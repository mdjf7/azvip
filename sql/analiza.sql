USE FudbalDB;
GO

SELECT TOP 10 WITH TIES
    p.name           AS igrac,
    cf.name          AS iz_kluba,
    ct.name          AS u_klub,
    d.season_label   AS sezona,
    t.transfer_fee   AS iznos_eur
FROM dbo.fact_transfer t
JOIN dbo.dim_player p ON p.player_id = t.player_id
JOIN dbo.dim_club cf  ON cf.club_id = t.from_club_id
JOIN dbo.dim_club ct  ON ct.club_id = t.to_club_id
JOIN dbo.dim_date d   ON d.date_key = t.date_key
WHERE t.transfer_fee > 0
  AND d.season BETWEEN 2021 AND 2025
  AND EXISTS (SELECT 1 FROM dbo.fact_club_match m
              WHERE m.club_id = t.to_club_id AND m.season = d.season AND m.competition_id = 'IT1')
ORDER BY t.transfer_fee DESC;

WITH pojacanja AS (
    SELECT p.name AS igrac, p.position AS pozicija, MIN(d.season_label) AS dosao,
           SUM(ISNULL(t.transfer_fee, 0)) AS placeno_eur,
           ISNULL(MAX(m.minuti), 0) AS minuti_za_como
    FROM dbo.fact_transfer t
    JOIN dbo.dim_player p ON p.player_id = t.player_id
    JOIN dbo.dim_date d   ON d.date_key = t.date_key
    LEFT JOIN (SELECT player_id, SUM(minutes_played) AS minuti
               FROM dbo.fact_appearance
               WHERE club_id = 1047
               GROUP BY player_id) m ON m.player_id = t.player_id
    WHERE t.to_club_id = 1047 AND d.season >= 2024
    GROUP BY t.player_id, p.name, p.position
)
SELECT igrac, pozicija, dosao, placeno_eur, minuti_za_como
FROM pojacanja
ORDER BY minuti_za_como DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;

WITH pojacanja AS (
    SELECT p.name AS igrac, p.position AS pozicija, MIN(d.season_label) AS dosao,
           SUM(ISNULL(t.transfer_fee, 0)) AS placeno_eur,
           ISNULL(MAX(m.minuti), 0) AS minuti_za_como
    FROM dbo.fact_transfer t
    JOIN dbo.dim_player p ON p.player_id = t.player_id
    JOIN dbo.dim_date d   ON d.date_key = t.date_key
    LEFT JOIN (SELECT player_id, SUM(minutes_played) AS minuti
               FROM dbo.fact_appearance
               WHERE club_id = 1047
               GROUP BY player_id) m ON m.player_id = t.player_id
    WHERE t.to_club_id = 1047 AND d.season >= 2024
    GROUP BY t.player_id, p.name, p.position
)
SELECT igrac, pozicija, dosao, placeno_eur, minuti_za_como
FROM pojacanja
ORDER BY minuti_za_como ASC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;

WITH kupovine AS (
    SELECT t.transfer_id, t.player_id, t.to_club_id, t.date_key, t.transfer_fee
    FROM dbo.fact_transfer t
    JOIN dbo.dim_date d ON d.date_key = t.date_key
    JOIN (SELECT DISTINCT club_id, season FROM dbo.fact_club_match WHERE competition_id = 'IT1') sa
         ON sa.club_id = t.to_club_id AND sa.season = d.season
    WHERE t.transfer_fee > 0 AND d.season BETWEEN 2021 AND 2025
),
nastupi AS (
    SELECT k.transfer_id, COUNT(a.appearance_id) AS broj_nastupa
    FROM kupovine k
    LEFT JOIN dbo.fact_appearance a
           ON a.player_id = k.player_id AND a.club_id = k.to_club_id AND a.date_key >= k.date_key
    GROUP BY k.transfer_id
)
SELECT
    c.name                                                             AS klub,
    COUNT(*)                                                           AS placenih_pojacanja,
    SUM(CASE WHEN n.broj_nastupa = 0 THEN 1 ELSE 0 END)                AS bez_ijednog_nastupa,
    SUM(CASE WHEN n.broj_nastupa = 0 THEN k.transfer_fee ELSE 0 END)   AS novac_bez_nastupa_eur
FROM kupovine k
INNER JOIN nastupi n     ON n.transfer_id = k.transfer_id
INNER JOIN dbo.dim_club c ON c.club_id = k.to_club_id
GROUP BY c.name
ORDER BY novac_bez_nastupa_eur DESC;

SELECT
    p.name                               AS igrac,
    p.position                           AS pozicija,
    cf.name                              AS iz_kluba,
    d.season_label                       AS sezona,
    t.transfer_fee                       AS iznos_eur,
    t.market_value_in_eur                AS vrednost_pri_dolasku,
    ISNULL(m.minuti, 0)                  AS minuti_za_como,
    v.market_value_in_eur                AS trenutna_vrednost,
    v.market_value_in_eur - t.market_value_in_eur AS promena_vrednosti
FROM dbo.fact_transfer t
INNER JOIN dbo.dim_player p ON p.player_id = t.player_id
INNER JOIN dbo.dim_club cf  ON cf.club_id = t.from_club_id
INNER JOIN dbo.dim_date d   ON d.date_key = t.date_key
LEFT JOIN (SELECT player_id, SUM(minutes_played) AS minuti
           FROM dbo.fact_appearance
           WHERE club_id = 1047
           GROUP BY player_id) m ON m.player_id = t.player_id
OUTER APPLY (SELECT TOP 1 fv.market_value_in_eur
             FROM dbo.fact_valuation fv
             WHERE fv.player_id = t.player_id
             ORDER BY fv.date_key DESC) v
WHERE t.to_club_id = 1047 AND d.season >= 2024
ORDER BY t.transfer_fee DESC;

WITH tokovi AS (
    SELECT t.to_club_id AS club_id, t.transfer_fee AS kupovina, 0 AS prodaja
    FROM dbo.fact_transfer t
    JOIN dbo.dim_date d ON d.date_key = t.date_key
    WHERE t.transfer_fee > 0 AND d.season BETWEEN 2021 AND 2025
    UNION ALL
    SELECT t.from_club_id, 0, t.transfer_fee
    FROM dbo.fact_transfer t
    JOIN dbo.dim_date d ON d.date_key = t.date_key
    WHERE t.transfer_fee > 0 AND d.season BETWEEN 2021 AND 2025
)
SELECT
    c.name                                   AS klub,
    SUM(tk.kupovina)                         AS kupovina_eur,
    SUM(tk.prodaja)                          AS prodaja_eur,
    SUM(tk.kupovina) - SUM(tk.prodaja)       AS neto_potrosnja_eur
FROM tokovi tk
JOIN dbo.dim_club c ON c.club_id = tk.club_id
WHERE EXISTS (SELECT 1 FROM dbo.fact_club_match m
              WHERE m.club_id = tk.club_id AND m.competition_id = 'IT1' AND m.season BETWEEN 2021 AND 2025)
GROUP BY c.name
HAVING SUM(tk.kupovina) - SUM(tk.prodaja) > 50000000
ORDER BY neto_potrosnja_eur DESC;

WITH minuti AS (
    SELECT player_id, SUM(minutes_played) AS minuti, MIN(date_key) AS prvi_nastup
    FROM dbo.fact_appearance
    WHERE club_id = 1047
    GROUP BY player_id
    HAVING SUM(minutes_played) >= 1000
),
vrednosti AS (
    SELECT m.player_id, m.minuti, poc.market_value_in_eur AS vrednost_na_pocetku, kraj.market_value_in_eur AS trenutna_vrednost
    FROM minuti m
    OUTER APPLY (SELECT TOP 1 fv.market_value_in_eur FROM dbo.fact_valuation fv
                 WHERE fv.player_id = m.player_id AND fv.date_key <= m.prvi_nastup
                 ORDER BY fv.date_key DESC) poc
    OUTER APPLY (SELECT TOP 1 fv.market_value_in_eur FROM dbo.fact_valuation fv
                 WHERE fv.player_id = m.player_id
                 ORDER BY fv.date_key DESC) kraj
)
SELECT p.name AS igrac, p.position AS pozicija, v.minuti, v.vrednost_na_pocetku, v.trenutna_vrednost,
       v.trenutna_vrednost - v.vrednost_na_pocetku AS rast_vrednosti
FROM vrednosti v
JOIN dbo.dim_player p ON p.player_id = v.player_id
WHERE v.trenutna_vrednost > v.vrednost_na_pocetku
ORDER BY rast_vrednosti DESC;

WITH igraci_sezone AS (
    SELECT DISTINCT a.club_id, d.season, a.player_id
    FROM dbo.fact_appearance a
    JOIN dbo.dim_date d ON d.date_key = a.date_key
    WHERE a.competition_id = 'IT1'
),
vrednost_tima AS (
    SELECT i.club_id, i.season, SUM(v.market_value_in_eur) AS vrednost_eur
    FROM igraci_sezone i
    CROSS APPLY (SELECT TOP 1 fv.market_value_in_eur FROM dbo.fact_valuation fv
                 WHERE fv.player_id = i.player_id AND fv.date_key <= i.season * 10000 + 801
                 ORDER BY fv.date_key DESC) v
    GROUP BY i.club_id, i.season
),
bodovi AS (
    SELECT club_id, season, COUNT(*) AS utakmica, SUM(points) AS bodova,
           AVG(CAST(points AS DECIMAL(5,2))) AS bodova_po_utakmici
    FROM dbo.fact_club_match
    WHERE competition_id = 'IT1'
    GROUP BY club_id, season
)
SELECT
    c.name                                                        AS klub,
    b.season                                                      AS sezona,
    b.utakmica,
    b.bodova,
    CAST(b.bodova_po_utakmici AS DECIMAL(4,2))                    AS bodova_po_utakmici,
    CAST(vt.vrednost_eur / 1000000.0 AS DECIMAL(8,1))             AS vrednost_tima_mil_eur,
    CAST(b.bodova / (vt.vrednost_eur / 1000000.0) AS DECIMAL(6,3)) AS bodova_po_milionu
FROM bodovi b
JOIN vrednost_tima vt ON vt.club_id = b.club_id AND vt.season = b.season
JOIN dbo.dim_club c   ON c.club_id = b.club_id
ORDER BY b.season, bodova_po_milionu DESC;

WITH igraci_sezone AS (
    SELECT DISTINCT a.club_id, d.season, a.player_id
    FROM dbo.fact_appearance a
    JOIN dbo.dim_date d ON d.date_key = a.date_key
    WHERE a.competition_id = 'IT1'
),
vrednost_tima AS (
    SELECT i.club_id, i.season, SUM(v.market_value_in_eur) AS vrednost_eur
    FROM igraci_sezone i
    CROSS APPLY (SELECT TOP 1 fv.market_value_in_eur FROM dbo.fact_valuation fv
                 WHERE fv.player_id = i.player_id AND fv.date_key <= i.season * 10000 + 801
                 ORDER BY fv.date_key DESC) v
    GROUP BY i.club_id, i.season
),
efikasnost AS (
    SELECT m.club_id, m.season, SUM(m.points) AS bodova, vt.vrednost_eur,
           SUM(m.points) / (vt.vrednost_eur / 1000000.0) AS bodova_po_milionu,
           CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.fact_club_match x
                                 WHERE x.club_id = m.club_id AND x.season = m.season - 1 AND x.competition_id = 'IT1')
                     AND m.season > 2021 THEN 1 ELSE 0 END AS promovisan,
           ROW_NUMBER() OVER (PARTITION BY m.season ORDER BY vt.vrednost_eur DESC) AS rang_po_vrednosti
    FROM dbo.fact_club_match m
    JOIN vrednost_tima vt ON vt.club_id = m.club_id AND vt.season = m.season
    WHERE m.competition_id = 'IT1'
    GROUP BY m.club_id, m.season, vt.vrednost_eur
),
como AS (
    SELECT season, rang_po_vrednosti FROM efikasnost WHERE club_id = 1047
)
SELECT
    e.season                                                                          AS sezona,
    CAST(MAX(CASE WHEN e.club_id = 1047 THEN e.bodova_po_milionu END) AS DECIMAL(6,3)) AS como,
    CAST(AVG(CASE WHEN ABS(e.rang_po_vrednosti - c.rang_po_vrednosti) BETWEEN 1 AND 3
                  THEN e.bodova_po_milionu END) AS DECIMAL(6,3))                       AS direktna_konkurencija,
    CAST(AVG(CASE WHEN e.promovisan = 1 AND e.club_id <> 1047
                  THEN e.bodova_po_milionu END) AS DECIMAL(6,3))                       AS ostali_promovisani,
    CAST(AVG(e.bodova_po_milionu) AS DECIMAL(6,3))                                    AS prosek_serie_a,
    MAX(CASE WHEN e.club_id = 1047 THEN e.rang_po_vrednosti END)                      AS como_rang_po_vrednosti
FROM efikasnost e
JOIN como c ON c.season = e.season
GROUP BY e.season
ORDER BY e.season;

SELECT DISTINCT
    p.position                                                                         AS pozicija,
    COUNT(*) OVER (PARTITION BY p.position)                                            AS broj_transfera,
    CAST(AVG(CAST(t.transfer_fee AS DECIMAL(18,0))) OVER (PARTITION BY p.position) / 1000000.0 AS DECIMAL(8,2)) AS prosek_mil_eur,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY t.transfer_fee)
         OVER (PARTITION BY p.position) / 1000000.0 AS DECIMAL(8,2))                   AS medijana_mil_eur
FROM dbo.fact_transfer t
JOIN dbo.dim_player p ON p.player_id = t.player_id
JOIN dbo.dim_date d   ON d.date_key = t.date_key
JOIN (SELECT DISTINCT club_id, season FROM dbo.fact_club_match WHERE competition_id = 'IT1') sa
     ON sa.club_id = t.to_club_id AND sa.season = d.season
WHERE t.transfer_fee > 0 AND d.season BETWEEN 2021 AND 2025
ORDER BY medijana_mil_eur DESC;

WITH igraci_sezone AS (
    SELECT DISTINCT a.club_id, d.season, a.player_id
    FROM dbo.fact_appearance a
    JOIN dbo.dim_date d ON d.date_key = a.date_key
    WHERE a.competition_id = 'IT1'
),
vrednost_tima AS (
    SELECT i.club_id, i.season, SUM(v.market_value_in_eur) AS vrednost_eur
    FROM igraci_sezone i
    CROSS APPLY (SELECT TOP 1 fv.market_value_in_eur FROM dbo.fact_valuation fv
                 WHERE fv.player_id = i.player_id AND fv.date_key <= i.season * 10000 + 801
                 ORDER BY fv.date_key DESC) v
    GROUP BY i.club_id, i.season
),
efikasnost AS (
    SELECT m.club_id, m.season, SUM(m.points) AS bodova, vt.vrednost_eur,
           SUM(m.points) / (vt.vrednost_eur / 1000000.0) AS bodova_po_milionu
    FROM dbo.fact_club_match m
    JOIN vrednost_tima vt ON vt.club_id = m.club_id AND vt.season = m.season
    WHERE m.competition_id = 'IT1'
    GROUP BY m.club_id, m.season, vt.vrednost_eur
)
SELECT
    c.name                                                                AS klub,
    e.season                                                              AS sezona,
    e.bodova,
    RANK() OVER (PARTITION BY e.season ORDER BY e.bodova DESC)            AS rang_po_bodovima,
    CAST(e.bodova_po_milionu AS DECIMAL(6,3))                             AS bodova_po_milionu,
    RANK() OVER (PARTITION BY e.season ORDER BY e.bodova_po_milionu DESC) AS rang_po_efikasnosti
FROM efikasnost e
JOIN dbo.dim_club c ON c.club_id = e.club_id
ORDER BY e.season, rang_po_efikasnosti;

WITH kupovine AS (
    SELECT
        CASE WHEN t.to_club_id = 1047 THEN 'Como' ELSE 'Ostali Serie A' END AS grupa,
        t.transfer_fee,
        DATEDIFF(DAY, p.date_of_birth, d.[date]) / 365.25 AS starost
    FROM dbo.fact_transfer t
    JOIN dbo.dim_player p ON p.player_id = t.player_id
    JOIN dbo.dim_date d   ON d.date_key = t.date_key
    JOIN (SELECT DISTINCT club_id, season FROM dbo.fact_club_match WHERE competition_id = 'IT1') sa
         ON sa.club_id = t.to_club_id AND sa.season = d.season
    WHERE t.transfer_fee > 0 AND d.season >= 2024
)
SELECT DISTINCT
    grupa,
    COUNT(*) OVER (PARTITION BY grupa)                                                          AS broj_kupovina,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY transfer_fee) OVER (PARTITION BY grupa)
         / 1000000.0 AS DECIMAL(8,2))                                                           AS medijana_cene_mil_eur,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY starost) OVER (PARTITION BY grupa)
         AS DECIMAL(4,1))                                                                       AS medijana_starosti
FROM kupovine;

WITH kumulativ AS (
    SELECT club_id, season, matchday,
           SUM(points) OVER (PARTITION BY club_id, season ORDER BY matchday
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)            AS bodova,
           SUM(goals_for - goals_against) OVER (PARTITION BY club_id, season ORDER BY matchday
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)            AS gol_razlika
    FROM dbo.fact_club_match
    WHERE competition_id = 'IT1' AND season >= 2024
),
tabela AS (
    SELECT club_id, season, matchday, bodova, gol_razlika,
           RANK() OVER (PARTITION BY season, matchday ORDER BY bodova DESC, gol_razlika DESC) AS pozicija
    FROM kumulativ
)
SELECT
    season                                                                  AS sezona,
    matchday                                                                AS kolo,
    bodova,
    gol_razlika,
    pozicija,
    LAG(pozicija) OVER (PARTITION BY season ORDER BY matchday) - pozicija   AS promena_pozicije
FROM tabela
WHERE club_id = 1047
ORDER BY season, matchday;

WITH kupovine AS (
    SELECT c.competition_id, c.name AS naziv_kluba, d.season, t.transfer_fee
    FROM dbo.fact_transfer t
    JOIN dbo.dim_date d ON d.date_key = t.date_key
    JOIN (SELECT DISTINCT club_id, season, competition_id FROM dbo.fact_club_match) l
         ON l.club_id = t.to_club_id AND l.season = d.season
    JOIN dbo.dim_club c ON c.club_id = t.to_club_id
    WHERE t.transfer_fee > 0 AND d.season BETWEEN 2021 AND 2025
)
SELECT
    CASE WHEN GROUPING(competition_id) = 1 THEN 'SVE LIGE' ELSE competition_id END         AS liga,
    CASE WHEN GROUPING(naziv_kluba) = 1 THEN 'SVI KLUBOVI' ELSE naziv_kluba END            AS klub,
    CASE WHEN GROUPING(season) = 1 THEN 'SVE SEZONE' ELSE CAST(season AS VARCHAR(4)) END   AS sezona,
    COUNT(*)                                                                               AS broj_kupovina,
    CAST(SUM(transfer_fee) / 1000000.0 AS DECIMAL(10,1))                                   AS potrosnja_mil_eur,
    GROUPING_ID(competition_id, naziv_kluba, season)                                       AS nivo
FROM kupovine
GROUP BY ROLLUP(competition_id, naziv_kluba, season)
ORDER BY GROUPING(competition_id), competition_id, GROUPING(naziv_kluba), naziv_kluba, GROUPING(season), season;

WITH kupovine AS (
    SELECT l.competition_id, p.position, t.transfer_fee
    FROM dbo.fact_transfer t
    JOIN dbo.dim_date d   ON d.date_key = t.date_key
    JOIN dbo.dim_player p ON p.player_id = t.player_id
    JOIN (SELECT DISTINCT club_id, season, competition_id FROM dbo.fact_club_match) l
         ON l.club_id = t.to_club_id AND l.season = d.season
    WHERE t.transfer_fee > 0 AND d.season BETWEEN 2021 AND 2025
)
SELECT
    CASE WHEN GROUPING(position) = 1 THEN 'SVE POZICIJE' ELSE position END        AS pozicija,
    CASE WHEN GROUPING(competition_id) = 1 THEN 'SVE LIGE' ELSE competition_id END AS liga,
    COUNT(*)                                                                      AS broj_kupovina,
    CAST(SUM(transfer_fee) / 1000000.0 AS DECIMAL(10,1))                          AS potrosnja_mil_eur,
    GROUPING_ID(position, competition_id)                                         AS nivo
FROM kupovine
GROUP BY CUBE(position, competition_id)
ORDER BY nivo, pozicija, liga;

SELECT
    CASE WHEN GROUPING(d.season_label) = 1 THEN 'UKUPNO' ELSE d.season_label END   AS sezona,
    CASE WHEN GROUPING(d.season_half) = 1 THEN 'SVE' ELSE d.season_half END        AS polusezona,
    CASE WHEN GROUPING(d.month_name) = 1 THEN 'SVI' ELSE d.month_name END          AS mesec,
    COUNT(*)                                                                       AS utakmica,
    SUM(m.points)                                                                  AS bodova,
    CAST(AVG(CAST(m.points AS DECIMAL(5,2))) AS DECIMAL(4,2))                      AS bodova_po_utakmici,
    GROUPING_ID(d.season_label, d.season_half, d.[month], d.month_name)            AS nivo
FROM dbo.fact_club_match m
JOIN dbo.dim_date d ON d.date_key = m.date_key
WHERE m.club_id = 1047 AND m.competition_id = 'IT1'
GROUP BY ROLLUP(d.season_label, d.season_half, (d.[month], d.month_name))
ORDER BY GROUPING(d.season_label), d.season_label, GROUPING(d.season_half), d.season_half,
         GROUPING(d.month_name), MIN(d.[date]);

SELECT
    CASE WHEN GROUPING(p.position) = 1 THEN 'SVE POZICIJE' ELSE p.position END     AS pozicija,
    CASE WHEN GROUPING(d.season_label) = 1 THEN 'SVE SEZONE' ELSE d.season_label END AS sezona,
    COUNT(*)                                                                       AS broj_kupovina,
    CAST(SUM(t.transfer_fee) / 1000000.0 AS DECIMAL(10,1))                         AS potrosnja_mil_eur,
    GROUPING_ID(p.position, d.season_label)                                        AS nivo
FROM dbo.fact_transfer t
JOIN dbo.dim_player p ON p.player_id = t.player_id
JOIN dbo.dim_date d   ON d.date_key = t.date_key
WHERE t.to_club_id = 1047 AND t.transfer_fee > 0 AND d.season >= 2024
GROUP BY CUBE(p.position, d.season_label)
ORDER BY nivo, pozicija, sezona;

WITH potrosnja AS (
    SELECT t.to_club_id AS club_id, d.season, SUM(t.transfer_fee) AS potrosnja_eur
    FROM dbo.fact_transfer t
    JOIN dbo.dim_date d ON d.date_key = t.date_key
    JOIN (SELECT DISTINCT club_id, season FROM dbo.fact_club_match WHERE competition_id = 'IT1') sa
         ON sa.club_id = t.to_club_id AND sa.season = d.season
    WHERE t.transfer_fee > 0 AND d.season BETWEEN 2021 AND 2025
    GROUP BY t.to_club_id, d.season
)
SELECT
    c.name                                                                                AS klub,
    p.season                                                                              AS sezona,
    CAST(p.potrosnja_eur / 1000000.0 AS DECIMAL(8,1))                                     AS potrosnja_mil_eur,
    CAST(100.0 * p.potrosnja_eur / SUM(p.potrosnja_eur) OVER (PARTITION BY p.season) AS DECIMAL(5,1)) AS udeo_u_ligi_pct,
    CAST(SUM(p.potrosnja_eur) OVER (PARTITION BY p.club_id ORDER BY p.season
                                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / 1000000.0
         AS DECIMAL(8,1))                                                                 AS kumulativno_mil_eur
FROM potrosnja p
JOIN dbo.dim_club c ON c.club_id = p.club_id
ORDER BY p.season, udeo_u_ligi_pct DESC;

WITH potrosnja AS (
    SELECT d.season_label, p.position, SUM(t.transfer_fee) AS potrosnja_eur
    FROM dbo.fact_transfer t
    JOIN dbo.dim_player p ON p.player_id = t.player_id
    JOIN dbo.dim_date d   ON d.date_key = t.date_key
    WHERE t.to_club_id = 1047 AND t.transfer_fee > 0 AND d.season >= 2024
    GROUP BY d.season_label, p.position
)
SELECT
    season_label                                                                              AS sezona,
    position                                                                                  AS pozicija,
    CAST(potrosnja_eur / 1000000.0 AS DECIMAL(8,1))                                           AS potrosnja_mil_eur,
    CAST(100.0 * potrosnja_eur / SUM(potrosnja_eur) OVER (PARTITION BY season_label) AS DECIMAL(5,1)) AS udeo_u_sezoni_pct,
    CAST(100.0 * SUM(potrosnja_eur) OVER (PARTITION BY position) / SUM(potrosnja_eur) OVER () AS DECIMAL(5,1)) AS udeo_ukupno_pct
FROM potrosnja
ORDER BY sezona, udeo_u_sezoni_pct DESC;

WITH promovisani AS (
    SELECT DISTINCT m.club_id, m.season
    FROM dbo.fact_club_match m
    WHERE m.competition_id = 'IT1' AND m.season >= 2024 AND m.club_id <> 1047
      AND NOT EXISTS (SELECT 1 FROM dbo.fact_club_match x
                      WHERE x.club_id = m.club_id AND x.season = m.season - 1 AND x.competition_id = 'IT1')
),
kumulativ AS (
    SELECT club_id, season, matchday,
           SUM(points) OVER (PARTITION BY club_id, season ORDER BY matchday
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS bodova
    FROM dbo.fact_club_match
    WHERE competition_id = 'IT1' AND season >= 2024
)
SELECT
    k.season                                                                AS sezona,
    k.matchday                                                              AS kolo,
    MAX(CASE WHEN k.club_id = 1047 THEN k.bodova END)                       AS como,
    CAST(AVG(CASE WHEN pr.club_id IS NOT NULL THEN k.bodova * 1.0 END) AS DECIMAL(5,1)) AS prosek_promovisanih,
    CAST(AVG(k.bodova * 1.0) AS DECIMAL(5,1))                               AS prosek_serie_a
FROM kumulativ k
LEFT JOIN promovisani pr ON pr.club_id = k.club_id AND pr.season = k.season
GROUP BY k.season, k.matchday
ORDER BY k.season, k.matchday;
