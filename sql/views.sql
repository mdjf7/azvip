USE FudbalDB;
GO

CREATE OR ALTER VIEW dbo.vw_player_season AS
WITH sezona_igraca AS (
    SELECT a.player_id, d.season, a.club_id, a.competition_id,
           COUNT(*)              AS nastupa,
           SUM(a.minutes_played) AS minuti,
           SUM(a.goals)          AS golova,
           SUM(a.assists)        AS asistencija
    FROM dbo.fact_appearance a
    JOIN dbo.dim_date d ON d.date_key = a.date_key
    GROUP BY a.player_id, d.season, a.club_id, a.competition_id
),
igrac_sezona AS (
    SELECT DISTINCT player_id, season
    FROM sezona_igraca
),
vrednost_pocetak AS (
    SELECT i.player_id, i.season, fv.market_value_in_eur,
           ROW_NUMBER() OVER (PARTITION BY i.player_id, i.season ORDER BY fv.date_key DESC) AS rb
    FROM igrac_sezona i
    JOIN dbo.fact_valuation fv ON fv.player_id = i.player_id
                              AND fv.date_key <= i.season * 10000 + 801
),
vrednost_kraj AS (
    SELECT i.player_id, i.season, fv.market_value_in_eur,
           ROW_NUMBER() OVER (PARTITION BY i.player_id, i.season ORDER BY fv.date_key DESC) AS rb
    FROM igrac_sezona i
    JOIN dbo.fact_valuation fv ON fv.player_id = i.player_id
                              AND fv.date_key <= (i.season + 1) * 10000 + 630
)
SELECT
    s.player_id,
    p.name                                                                         AS igrac,
    p.position                                                                     AS pozicija,
    p.sub_position                                                                 AS podpozicija,
    s.season                                                                       AS sezona,
    s.club_id,
    c.name                                                                         AS klub,
    s.competition_id                                                               AS liga,
    CAST(DATEDIFF(DAY, p.date_of_birth, DATEFROMPARTS(s.season, 8, 1)) / 365.25 AS DECIMAL(4,1)) AS starost,
    s.nastupa,
    s.minuti,
    s.golova,
    s.asistencija,
    CAST(90.0 * (s.golova + s.asistencija) / NULLIF(s.minuti, 0) AS DECIMAL(5,2))  AS ga_po_90,
    vp.market_value_in_eur                                                         AS vrednost_pocetak,
    vk.market_value_in_eur                                                         AS vrednost_kraj
FROM sezona_igraca s
JOIN dbo.dim_player p ON p.player_id = s.player_id
JOIN dbo.dim_club c   ON c.club_id = s.club_id
LEFT JOIN vrednost_pocetak vp ON vp.player_id = s.player_id AND vp.season = s.season AND vp.rb = 1
LEFT JOIN vrednost_kraj vk    ON vk.player_id = s.player_id AND vk.season = s.season AND vk.rb = 1;
GO

IF OBJECT_ID('dbo.player_season_stats', 'U') IS NOT NULL DROP TABLE dbo.player_season_stats;
GO

SELECT *
INTO dbo.player_season_stats
FROM dbo.vw_player_season;
GO

SELECT COUNT(*) AS redova FROM dbo.player_season_stats;
