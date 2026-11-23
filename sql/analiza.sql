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
  AND ct.competition_id = 'IT1'
ORDER BY t.transfer_fee DESC;

SELECT
    p.name           AS igrac,
    p.position       AS pozicija,
    d.season_label   AS sezona,
    t.transfer_fee   AS iznos_eur
FROM dbo.fact_transfer t
JOIN dbo.dim_player p ON p.player_id = t.player_id
JOIN dbo.dim_date d   ON d.date_key = t.date_key
WHERE t.to_club_id = 1047 AND t.transfer_fee > 0
ORDER BY t.transfer_fee DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;
GO


SELECT
    p.name                      AS igrac,
    p.position                  AS pozicija,
    d.season_label              AS dosao,
    t.transfer_fee              AS placeno_eur,
    ISNULL(s.minuti, 0)         AS minuti_za_como,
    s.vrednost_sada             AS vrednost_sada_eur
FROM dbo.fact_transfer t
INNER JOIN dbo.dim_player p ON p.player_id = t.player_id
INNER JOIN dbo.dim_date d   ON d.date_key = t.date_key
LEFT JOIN (SELECT player_id,
                  SUM(minuti) AS minuti,
                  MAX(CASE WHEN sezona = 2025 THEN vrednost_kraj END) AS vrednost_sada
           FROM dbo.player_season_stats
           WHERE club_id = 1047
           GROUP BY player_id) s ON s.player_id = t.player_id
WHERE t.to_club_id = 1047 AND t.transfer_fee > 0
ORDER BY t.transfer_fee DESC;
GO


WITH tokovi AS (
    SELECT to_club_id AS club_id, transfer_fee AS kupovina, 0 AS prodaja, date_key
    FROM dbo.fact_transfer
    WHERE transfer_fee > 0
    UNION ALL
    SELECT from_club_id, 0, transfer_fee, date_key
    FROM dbo.fact_transfer
    WHERE transfer_fee > 0
)
SELECT
    c.name                                AS klub,
    SUM(tk.kupovina)                      AS kupovina_eur,
    SUM(tk.prodaja)                       AS prodaja_eur,
    SUM(tk.kupovina) - SUM(tk.prodaja)    AS neto_potrosnja_eur
FROM tokovi tk
JOIN dbo.dim_club c ON c.club_id = tk.club_id
JOIN dbo.dim_date d ON d.date_key = tk.date_key
WHERE c.competition_id = 'IT1'
  AND d.season BETWEEN 2021 AND 2025
GROUP BY c.name
HAVING SUM(tk.kupovina) - SUM(tk.prodaja) > 50000000
ORDER BY neto_potrosnja_eur DESC;
GO


WITH vrednost AS (
    SELECT club_id, sezona, SUM(vrednost_pocetak) AS vrednost_tima
    FROM dbo.player_season_stats
    WHERE liga = 'IT1'
    GROUP BY club_id, sezona
),
efikasnost AS (
    SELECT
        m.club_id,
        m.season,
        COUNT(*)                                            AS utakmica,
        SUM(m.points)                                       AS bodova,
        AVG(CAST(m.points AS DECIMAL(4,2)))                 AS bodova_po_utakmici,
        SUM(m.points) / (v.vrednost_tima / 1000000.0)       AS bodova_po_milionu,
        ROW_NUMBER() OVER (PARTITION BY m.season ORDER BY v.vrednost_tima DESC) AS rang_po_vrednosti
    FROM dbo.fact_club_match m
    JOIN vrednost v ON v.club_id = m.club_id AND v.sezona = m.season
    WHERE m.competition_id = 'IT1'
    GROUP BY m.club_id, m.season, v.vrednost_tima
),
como AS (
    SELECT * FROM efikasnost WHERE club_id = 1047
)
SELECT
    c.season                                                       AS sezona,
    c.utakmica,
    c.bodova,
    CAST(c.bodova_po_utakmici AS DECIMAL(4,2))                     AS bodova_po_utakmici,
    c.rang_po_vrednosti                                            AS como_rang_po_vrednosti,
    CAST(c.bodova_po_milionu AS DECIMAL(5,3))                      AS como_bodova_po_milionu,
    CAST(AVG(CASE WHEN ABS(e.rang_po_vrednosti - c.rang_po_vrednosti) BETWEEN 1 AND 3
                  THEN e.bodova_po_milionu END) AS DECIMAL(5,3))   AS konkurencija_bodova_po_milionu,
    CAST(AVG(e.bodova_po_milionu) AS DECIMAL(5,3))                 AS liga_bodova_po_milionu
FROM como c
JOIN efikasnost e ON e.season = c.season
GROUP BY c.season, c.utakmica, c.bodova, c.bodova_po_utakmici, c.rang_po_vrednosti, c.bodova_po_milionu
ORDER BY c.season;
GO


SELECT DISTINCT
    p.position                                                                              AS pozicija,
    COUNT(*) OVER (PARTITION BY p.position)                                                 AS broj_transfera,
    CAST(AVG(t.transfer_fee * 1.0) OVER (PARTITION BY p.position) / 1000000 AS DECIMAL(6,2)) AS prosek_mil_eur,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY t.transfer_fee)
         OVER (PARTITION BY p.position) / 1000000 AS DECIMAL(6,2))                          AS medijana_mil_eur
FROM dbo.fact_transfer t
JOIN dbo.dim_player p ON p.player_id = t.player_id
JOIN dbo.dim_club c   ON c.club_id = t.to_club_id
JOIN dbo.dim_date d   ON d.date_key = t.date_key
WHERE t.transfer_fee > 0 AND c.competition_id = 'IT1' AND d.season BETWEEN 2021 AND 2025
ORDER BY medijana_mil_eur DESC;

WITH kumulativ AS (
    SELECT club_id, season, matchday,
           SUM(points) OVER (PARTITION BY club_id, season ORDER BY matchday
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS bodova,
           SUM(goals_for - goals_against) OVER (PARTITION BY club_id, season ORDER BY matchday
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS gol_razlika
    FROM dbo.fact_club_match
    WHERE competition_id = 'IT1' AND season >= 2024
),
tabela AS (
    SELECT club_id, season, matchday, bodova,
           RANK() OVER (PARTITION BY season, matchday ORDER BY bodova DESC, gol_razlika DESC) AS pozicija
    FROM kumulativ
)
SELECT
    season                                                                  AS sezona,
    matchday                                                                AS kolo,
    bodova,
    pozicija,
    LAG(pozicija) OVER (PARTITION BY season ORDER BY matchday) - pozicija   AS promena_pozicije
FROM tabela
WHERE club_id = 1047
ORDER BY season, matchday;
GO


SELECT
    CASE WHEN GROUPING(d.season_label) = 1 THEN 'UKUPNO' ELSE d.season_label END   AS sezona,
    CASE WHEN GROUPING(d.season_half) = 1 THEN 'SVE' ELSE d.season_half END        AS polusezona,
    CASE WHEN GROUPING(d.month_name) = 1 THEN 'SVI' ELSE d.month_name END          AS mesec,
    COUNT(*)                                                                       AS utakmica,
    SUM(m.points)                                                                  AS bodova,
    CAST(AVG(CAST(m.points AS DECIMAL(4,2))) AS DECIMAL(4,2))                      AS bodova_po_utakmici,
    CAST(AVG(CAST(m.goals_against AS DECIMAL(4,2))) AS DECIMAL(4,2))               AS primljeno_po_utakmici
FROM dbo.fact_club_match m
JOIN dbo.dim_date d ON d.date_key = m.date_key
WHERE m.club_id = 1047 AND m.competition_id = 'IT1'
GROUP BY ROLLUP(d.season_label, d.season_half, (d.[month], d.month_name))
ORDER BY GROUPING(d.season_label), d.season_label, GROUPING(d.season_half), d.season_half,
         GROUPING(d.month_name), MIN(d.[date]);

SELECT
    CASE WHEN GROUPING(p.position) = 1 THEN 'SVE POZICIJE' ELSE p.position END   AS pozicija,
    CASE WHEN GROUPING(c.competition_id) = 1 THEN 'SVE LIGE' ELSE c.competition_id END AS liga,
    COUNT(*)                                                                     AS broj_kupovina,
    CAST(SUM(t.transfer_fee) / 1000000.0 AS DECIMAL(8,1))                        AS potrosnja_mil_eur
FROM dbo.fact_transfer t
JOIN dbo.dim_player p ON p.player_id = t.player_id
JOIN dbo.dim_club c   ON c.club_id = t.to_club_id
JOIN dbo.dim_date d   ON d.date_key = t.date_key
WHERE t.transfer_fee > 0 AND c.competition_id IN ('GB1', 'ES1', 'IT1', 'L1', 'FR1') AND d.season BETWEEN 2021 AND 2025
GROUP BY CUBE(p.position, c.competition_id)
ORDER BY GROUPING(p.position), pozicija, GROUPING(c.competition_id), liga;
GO


WITH potrosnja AS (
    SELECT t.to_club_id AS club_id, d.season, SUM(t.transfer_fee) AS potrosnja_eur
    FROM dbo.fact_transfer t
    JOIN dbo.dim_date d ON d.date_key = t.date_key
    JOIN dbo.dim_club c ON c.club_id = t.to_club_id
    WHERE t.transfer_fee > 0 AND c.competition_id = 'IT1' AND d.season BETWEEN 2021 AND 2025
    GROUP BY t.to_club_id, d.season
)
SELECT
    c.name                                                                            AS klub,
    p.season                                                                          AS sezona,
    CAST(p.potrosnja_eur / 1000000.0 AS DECIMAL(8,1))                                 AS potrosnja_mil_eur,
    CAST(100.0 * p.potrosnja_eur / SUM(p.potrosnja_eur) OVER (PARTITION BY p.season)
         AS DECIMAL(5,1))                                                             AS udeo_u_ligi_pct,
    CAST(SUM(p.potrosnja_eur) OVER (PARTITION BY p.club_id ORDER BY p.season
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / 1000000.0 AS DECIMAL(8,1)) AS kumulativno_mil_eur
FROM potrosnja p
JOIN dbo.dim_club c ON c.club_id = p.club_id
ORDER BY p.season, udeo_u_ligi_pct DESC;
GO


SELECT
    d.season_label                                                                 AS sezona,
    m.matchday                                                                     AS kolo,
    m.points                                                                       AS bodova,
    m.goals_against                                                                AS primljeno,
    CAST(AVG(CAST(m.points AS DECIMAL(4,2))) OVER (ORDER BY m.date_key
         ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS DECIMAL(4,2))                AS forma_bodova_5,
    SUM(m.goals_against) OVER (ORDER BY m.date_key
         ROWS BETWEEN 4 PRECEDING AND CURRENT ROW)                                 AS primljeno_u_5
FROM dbo.fact_club_match m
JOIN dbo.dim_date d ON d.date_key = m.date_key
WHERE m.club_id = 1047 AND m.competition_id = 'IT1'
ORDER BY m.date_key;

WITH prozori AS (
    SELECT manager_name,
           LAG(manager_name) OVER (PARTITION BY club_id, season ORDER BY date_key) AS prethodni_trener,
           AVG(CAST(points AS DECIMAL(4,2))) OVER (PARTITION BY club_id, season ORDER BY date_key
               ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING)                         AS bodova_pre,
           AVG(CAST(points AS DECIMAL(4,2))) OVER (PARTITION BY club_id, season ORDER BY date_key
               ROWS BETWEEN CURRENT ROW AND 9 FOLLOWING)                          AS bodova_posle,
           COUNT(*) OVER (PARTITION BY club_id, season ORDER BY date_key
               ROWS BETWEEN 10 PRECEDING AND 9 FOLLOWING)                         AS utakmica_u_prozoru
    FROM dbo.fact_club_match
)
SELECT
    CASE WHEN manager_name <> prethodni_trener THEN 'Smena trenera' ELSE 'Bez smene' END AS odluka,
    COUNT(*)                                             AS slucajeva,
    CAST(AVG(bodova_pre) AS DECIMAL(4,2))                AS bodova_po_utakmici_pre,
    CAST(AVG(bodova_posle) AS DECIMAL(4,2))              AS bodova_po_utakmici_posle,
    CAST(AVG(bodova_posle - bodova_pre) AS DECIMAL(4,2)) AS poboljsanje
FROM prozori
WHERE utakmica_u_prozoru = 20 AND bodova_pre <= 1.0 AND prethodni_trener IS NOT NULL
GROUP BY CASE WHEN manager_name <> prethodni_trener THEN 'Smena trenera' ELSE 'Bez smene' END;
GO


WITH tabela AS (
    SELECT club_id, season,
           RANK() OVER (PARTITION BY season ORDER BY SUM(points) DESC) AS plasman
    FROM dbo.fact_club_match
    WHERE competition_id = 'IT1'
    GROUP BY club_id, season
),
utakmice AS (
    SELECT
        CASE WHEN t.plasman <= 7 THEN '1. Top 7' WHEN t.plasman <= 14 THEN '2. Sredina' ELSE '3. Donji deo' END AS protivnik,
        m.season,
        CAST(m.points AS DECIMAL(4,2)) AS bodova
    FROM dbo.fact_club_match m
    JOIN tabela t ON t.club_id = m.opponent_id AND t.season = m.season
    WHERE m.club_id = 1047 AND m.competition_id = 'IT1'
)
SELECT protivnik, season AS sezona, CAST(AVG(bodova) AS DECIMAL(4,2)) AS bodova_po_utakmici
FROM utakmice
GROUP BY protivnik, season
ORDER BY protivnik, season;

WITH tabela AS (
    SELECT club_id, season,
           RANK() OVER (PARTITION BY season ORDER BY SUM(points) DESC) AS plasman
    FROM dbo.fact_club_match
    WHERE competition_id = 'IT1'
    GROUP BY club_id, season
),
utakmice AS (
    SELECT
        CASE WHEN t.plasman <= 7 THEN '1. Top 7' WHEN t.plasman <= 14 THEN '2. Sredina' ELSE '3. Donji deo' END AS protivnik,
        m.season,
        CAST(m.points AS DECIMAL(4,2)) AS bodova
    FROM dbo.fact_club_match m
    JOIN tabela t ON t.club_id = m.opponent_id AND t.season = m.season
    WHERE m.club_id = 1047 AND m.competition_id = 'IT1'
)
SELECT
    protivnik,
    CAST([2024] AS DECIMAL(4,2))          AS [2024/25],
    CAST([2025] AS DECIMAL(4,2))          AS [2025/26],
    CAST([2025] - [2024] AS DECIMAL(4,2)) AS napredak
FROM utakmice
PIVOT (AVG(bodova) FOR season IN ([2024], [2025])) pv
ORDER BY protivnik;
GO


SELECT igrac, klub, sezona, starost, minuti, golova, asistencija, ga_po_90, vrednost_pocetak, vrednost_kraj
FROM dbo.player_season_stats
WHERE igrac = 'Nico Paz'
ORDER BY sezona;

WITH mladi_ofanzivci AS (
    SELECT igrac, sezona, ga_po_90,
           PERCENT_RANK() OVER (PARTITION BY sezona ORDER BY ga_po_90) AS percentil
    FROM dbo.player_season_stats
    WHERE liga = 'IT1' AND pozicija IN ('Midfield', 'Attack') AND starost <= 23 AND minuti >= 1500
)
SELECT igrac, sezona, ga_po_90, CAST(100 * percentil AS DECIMAL(4,1)) AS bolji_od_pct_igraca
FROM mladi_ofanzivci
WHERE igrac = 'Nico Paz';

WITH slicni AS (
    SELECT 1.0 * sledeca.vrednost_kraj / a.vrednost_kraj AS koeficijent
    FROM dbo.player_season_stats a
    JOIN dbo.player_season_stats sledeca ON sledeca.player_id = a.player_id AND sledeca.sezona = a.sezona + 1
    WHERE a.sezona BETWEEN 2021 AND 2024
      AND a.starost BETWEEN 20 AND 23
      AND a.minuti >= 2000
      AND a.ga_po_90 >= 0.45
      AND a.pozicija IN ('Midfield', 'Attack')
      AND a.vrednost_kraj BETWEEN 50000000 AND 120000000
)
SELECT DISTINCT
    COUNT(*) OVER ()                                                                                  AS slicnih_igraca,
    CAST(100 * AVG(CASE WHEN koeficijent > 1 THEN 1.0 ELSE 0 END) OVER () AS DECIMAL(4,1))            AS pct_kojima_je_vrednost_rasla,
    CAST(80 * PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY koeficijent) OVER () AS DECIMAL(5,1))      AS paz_pesimisticno_mil,
    CAST(80 * PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY koeficijent) OVER () AS DECIMAL(5,1))      AS paz_medijana_mil,
    CAST(80 * PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY koeficijent) OVER () AS DECIMAL(5,1))      AS paz_optimisticno_mil
FROM slicni;
GO
