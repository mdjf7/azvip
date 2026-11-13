"""
filter_dataset.py
-----------------
Cuts the full Transfermarkt dataset (dcaribou/transfermarkt-datasets) down to
the scope of this project, so it can be loaded into SQL Server and carried
around in a GitHub repo.

Scope (change in CONFIG below):
  * leagues : top 5 European leagues (GB1, ES1, IT1, L1, FR1)
  * seasons : 2021/22 - 2025/26   (Transfermarkt season 2021 = 2021/22)
  * history : transfers and market valuations of the selected players
              from 2016-07-01 on, so buy prices before 2021 are known
              (needed for transfer ROI)

Usage (Windows, from the repo root):
    pip install pandas
    python scripts/filter_dataset.py --src C:\\azivp\\raw --out data

--src : folder with the original CSV files (unzipped transfermarkt-datasets.zip
        or the Kaggle download; .csv and .csv.gz both work)
--out : where the filtered CSV files and data.zip are written
"""

import argparse
import zipfile
from pathlib import Path

import pandas as pd

# ----------------------------------------------------------------------------
# CONFIG
# ----------------------------------------------------------------------------
LEAGUES = ["GB1", "ES1", "IT1", "L1", "FR1"]   # add "SER1" for Serbian SuperLiga
SEASONS = [2021, 2022, 2023, 2024, 2025]       # 2025 = season 2025/26
HISTORY_FROM = "2016-07-01"                    # transfers/valuations kept from here
CHUNK = 500_000                                # rows per chunk for big files

# Columns we never need in SQL (links, images, scraper internals)
DROP_IF_CONTAINS = ("url", "image", "filename")


# ----------------------------------------------------------------------------
# helpers
# ----------------------------------------------------------------------------
def find_file(src: Path, name: str) -> Path:
    """Return <name>.csv or <name>.csv.gz from src (searches subfolders too)."""
    for pattern in (f"{name}.csv", f"{name}.csv.gz"):
        hits = list(src.rglob(pattern))
        if hits:
            return hits[0]
    raise FileNotFoundError(f"{name}.csv(.gz) not found under {src}")


def clean_columns(df: pd.DataFrame) -> pd.DataFrame:
    keep = [c for c in df.columns if not any(k in c.lower() for k in DROP_IF_CONTAINS)]
    return df[keep]


def read_filtered(src: Path, name: str, mask_fn) -> pd.DataFrame:
    """Read a (possibly huge) CSV in chunks and keep only rows where mask_fn is True."""
    parts = []
    for chunk in pd.read_csv(find_file(src, name), chunksize=CHUNK, low_memory=False):
        parts.append(chunk[mask_fn(chunk)])
    df = pd.concat(parts, ignore_index=True) if parts else pd.DataFrame()
    return clean_columns(df)


def read_all(src: Path, name: str) -> pd.DataFrame:
    return clean_columns(pd.read_csv(find_file(src, name), low_memory=False))


def save(df: pd.DataFrame, out: Path, name: str, report: list) -> None:
    path = out / f"{name}.csv"
    # UTF-8 with BOM-less encoding; BULK INSERT reads it with CODEPAGE = '65001'
    df.to_csv(path, index=False, encoding="utf-8", date_format="%Y-%m-%d")
    report.append((name, len(df), path.stat().st_size / 1_048_576))


# ----------------------------------------------------------------------------
# main
# ----------------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", required=True, type=Path, help="folder with original CSVs")
    ap.add_argument("--out", default=Path("data"), type=Path, help="output folder")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    report = []

    # 1) games: the backbone - everything else is filtered through these
    games = read_filtered(
        args.src, "games",
        lambda d: d["competition_id"].isin(LEAGUES) & d["season"].isin(SEASONS),
    )
    game_ids = set(games["game_id"])
    club_ids = set(games["home_club_id"]) | set(games["away_club_id"])
    print(f"games: {len(games):,} | clubs in scope: {len(club_ids)}")

    # 2) one row per club per game (home + away) - basis for fact_club_match
    club_games = read_filtered(args.src, "club_games", lambda d: d["game_id"].isin(game_ids))

    # 3) appearances and in-game events of those games (largest files)
    appearances = read_filtered(args.src, "appearances", lambda d: d["game_id"].isin(game_ids))
    game_events = read_filtered(args.src, "game_events", lambda d: d["game_id"].isin(game_ids))
    player_ids = set(appearances["player_id"])
    print(f"appearances: {len(appearances):,} | players in scope: {len(player_ids):,}")

    # 4) transfers of those players since HISTORY_FROM
    transfers = read_filtered(args.src, "transfers", lambda d: d["player_id"].isin(player_ids))
    transfers = transfers[pd.to_datetime(transfers["transfer_date"], errors="coerce") >= HISTORY_FROM]

    # 5) market value history of those players since HISTORY_FROM
    valuations = read_filtered(args.src, "player_valuations", lambda d: d["player_id"].isin(player_ids))
    valuations = valuations[pd.to_datetime(valuations["date"], errors="coerce") >= HISTORY_FROM]

    # 6) dimensions: players, clubs (incl. transfer counterparties), competitions
    players = read_all(args.src, "players")
    players = players[players["player_id"].isin(player_ids)]

    transfer_club_ids = set(transfers["from_club_id"].dropna()) | set(transfers["to_club_id"].dropna())
    clubs = read_all(args.src, "clubs")
    clubs = clubs[clubs["club_id"].isin(club_ids | transfer_club_ids)]

    comp_ids = set(games["competition_id"]) | set(clubs["domestic_competition_id"].dropna())
    competitions = read_all(args.src, "competitions")
    competitions = competitions[competitions["competition_id"].isin(comp_ids)]

    # 7) write
    for name, df in [
        ("competitions", competitions), ("clubs", clubs), ("players", players),
        ("games", games), ("club_games", club_games), ("appearances", appearances),
        ("game_events", game_events), ("transfers", transfers),
        ("player_valuations", valuations),
    ]:
        save(df, args.out, name, report)

    # 8) zip everything (GitHub limit: 100 MB per file)
    zip_path = args.out / "data.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for name, _, _ in report:
            z.write(args.out / f"{name}.csv", arcname=f"{name}.csv")

    print("\n{:<20}{:>12}{:>10}".format("table", "rows", "MB"))
    for name, rows, mb in report:
        print(f"{name:<20}{rows:>12,}{mb:>10.1f}")
    print(f"\ndata.zip: {zip_path.stat().st_size / 1_048_576:.1f} MB -> {zip_path}")


if __name__ == "__main__":
    main()
