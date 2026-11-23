USE FudbalDB;
GO

TRUNCATE TABLE dbo.fact_valuation;
TRUNCATE TABLE dbo.fact_transfer;
TRUNCATE TABLE dbo.fact_appearance;
TRUNCATE TABLE dbo.fact_club_match;
DELETE FROM dbo.dim_player;
DELETE FROM dbo.dim_club;
DELETE FROM dbo.dim_competition;
DELETE FROM dbo.dim_date;
GO

WITH dani AS (
    SELECT CAST('2016-07-01' AS DATE) AS dt
    UNION ALL
    SELECT DATEADD(DAY, 1, dt) FROM dani WHERE dt < '2026-07-31'
)
INSERT INTO dbo.dim_date (date_key, [date], [year], [quarter], [month], month_name, season, season_label, season_half)
SELECT
    CONVERT(INT, CONVERT(CHAR(8), dt, 112)),
    dt,
    YEAR(dt),
    DATEPART(QUARTER, dt),
    MONTH(dt),
    DATENAME(MONTH, dt),
    CASE WHEN MONTH(dt) >= 7 THEN YEAR(dt) ELSE YEAR(dt) - 1 END,
    CASE WHEN MONTH(dt) >= 7
         THEN CAST(YEAR(dt) AS NVARCHAR(4)) + N'/' + RIGHT(CAST(YEAR(dt) + 1 AS NVARCHAR(4)), 2)
         ELSE CAST(YEAR(dt) - 1 AS NVARCHAR(4)) + N'/' + RIGHT(CAST(YEAR(dt) AS NVARCHAR(4)), 2) END,
    CASE WHEN MONTH(dt) >= 7 THEN N'Jesen' ELSE N'Prolece' END
FROM dani
OPTION (MAXRECURSION 0);
GO

INSERT INTO dbo.dim_competition (competition_id, name, country_name, type)
SELECT competition_id, competition_code, country_name, type
FROM stg.competitions;
GO

INSERT INTO dbo.dim_club (club_id, name, competition_id, stadium_name, stadium_seats, is_top5)
SELECT
    c.club_id,
    c.name,
    comp.competition_id,
    c.stadium_name,
    c.stadium_seats,
    CASE WHEN EXISTS (SELECT 1 FROM stg.club_games cg WHERE cg.club_id = c.club_id) THEN 1 ELSE 0 END
FROM stg.clubs c
LEFT JOIN stg.competitions comp ON comp.competition_id = c.domestic_competition_id;

INSERT INTO dbo.dim_club (club_id, name, competition_id, stadium_name, stadium_seats, is_top5)
SELECT x.club_id, MAX(x.name), NULL, NULL, NULL, 0
FROM (
    SELECT from_club_id, from_club_name FROM stg.transfers
    UNION ALL
    SELECT to_club_id, to_club_name FROM stg.transfers
    UNION ALL
    SELECT current_club_id, current_club_name FROM stg.player_valuations
) x (club_id, name)
WHERE x.club_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM stg.clubs c WHERE c.club_id = x.club_id)
GROUP BY x.club_id;
GO

INSERT INTO dbo.dim_player (player_id, name, country_of_citizenship, position, sub_position, foot, height_in_cm, date_of_birth)
SELECT player_id, name, country_of_citizenship, position, sub_position, foot, height_in_cm, date_of_birth
FROM stg.players;
GO

INSERT INTO dbo.fact_club_match (game_id, club_id, opponent_id, date_key, competition_id, season, matchday, is_home,
                                 goals_for, goals_against, points, result, manager_name, attendance)
SELECT
    cg.game_id,
    cg.club_id,
    cg.opponent_id,
    CONVERT(INT, CONVERT(CHAR(8), g.[date], 112)),
    g.competition_id,
    g.season,
    CASE WHEN CHARINDEX('.', g.round) > 1 THEN TRY_CAST(LEFT(g.round, CHARINDEX('.', g.round) - 1) AS INT) END,
    CASE WHEN cg.hosting = 'Home' THEN 1 ELSE 0 END,
    cg.own_goals,
    cg.opponent_goals,
    CASE WHEN cg.own_goals > cg.opponent_goals THEN 3
         WHEN cg.own_goals = cg.opponent_goals THEN 1
         ELSE 0 END,
    CASE WHEN cg.own_goals > cg.opponent_goals THEN 'W'
         WHEN cg.own_goals = cg.opponent_goals THEN 'D'
         ELSE 'L' END,
    cg.own_manager_name,
    g.attendance
FROM stg.club_games cg
JOIN stg.games g ON g.game_id = cg.game_id;
GO

INSERT INTO dbo.fact_appearance (appearance_id, game_id, date_key, player_id, club_id, competition_id,
                                 minutes_played, goals, assists, yellow_cards, red_cards)
SELECT
    appearance_id,
    game_id,
    CONVERT(INT, CONVERT(CHAR(8), [date], 112)),
    player_id,
    player_club_id,
    competition_id,
    minutes_played,
    goals,
    assists,
    yellow_cards,
    red_cards
FROM stg.appearances;
GO

INSERT INTO dbo.fact_transfer (player_id, date_key, transfer_season, from_club_id, to_club_id, transfer_fee, market_value_in_eur)
SELECT
    player_id,
    CONVERT(INT, CONVERT(CHAR(8), transfer_date, 112)),
    transfer_season,
    from_club_id,
    to_club_id,
    transfer_fee,
    market_value_in_eur
FROM stg.transfers
WHERE transfer_date BETWEEN '2016-07-01' AND '2026-07-06';
GO

INSERT INTO dbo.fact_valuation (player_id, date_key, club_id, market_value_in_eur)
SELECT
    player_id,
    CONVERT(INT, CONVERT(CHAR(8), [date], 112)),
    current_club_id,
    market_value_in_eur
FROM stg.player_valuations
WHERE market_value_in_eur IS NOT NULL;
GO

SELECT 'dim_date' AS tabela, COUNT(*) AS redova FROM dbo.dim_date UNION ALL
SELECT 'dim_competition', COUNT(*) FROM dbo.dim_competition UNION ALL
SELECT 'dim_club', COUNT(*) FROM dbo.dim_club UNION ALL
SELECT 'dim_player', COUNT(*) FROM dbo.dim_player UNION ALL
SELECT 'fact_club_match', COUNT(*) FROM dbo.fact_club_match UNION ALL
SELECT 'fact_appearance', COUNT(*) FROM dbo.fact_appearance UNION ALL
SELECT 'fact_transfer', COUNT(*) FROM dbo.fact_transfer UNION ALL
SELECT 'fact_valuation', COUNT(*) FROM dbo.fact_valuation;
