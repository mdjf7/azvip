USE FudbalDB;
GO

TRUNCATE TABLE stg.competitions;
TRUNCATE TABLE stg.clubs;
TRUNCATE TABLE stg.players;
TRUNCATE TABLE stg.games;
TRUNCATE TABLE stg.club_games;
TRUNCATE TABLE stg.appearances;
TRUNCATE TABLE stg.game_events;
TRUNCATE TABLE stg.transfers;
TRUNCATE TABLE stg.player_valuations;
GO

BULK INSERT stg.competitions
FROM 'C:\azvip\azvip\data\competitions.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT stg.clubs
FROM 'C:\azvip\azvip\data\clubs.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT stg.players
FROM 'C:\azvip\azvip\data\players.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT stg.games
FROM 'C:\azvip\azvip\data\games.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT stg.club_games
FROM 'C:\azvip\azvip\data\club_games.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT stg.appearances
FROM 'C:\azvip\azvip\data\appearances.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT stg.game_events
FROM 'C:\azvip\azvip\data\game_events.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT stg.transfers
FROM 'C:\azvip\azvip\data\transfers.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT stg.player_valuations
FROM 'C:\azvip\azvip\data\player_valuations.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
GO

SELECT 'competitions'      AS tabela, COUNT(*) AS redova, 31     AS ocekivano FROM stg.competitions      UNION ALL
SELECT 'clubs',                       COUNT(*),           677                 FROM stg.clubs             UNION ALL
SELECT 'players',                     COUNT(*),           5526                FROM stg.players           UNION ALL
SELECT 'games',                       COUNT(*),           8908                FROM stg.games             UNION ALL
SELECT 'club_games',                  COUNT(*),           17816               FROM stg.club_games        UNION ALL
SELECT 'appearances',                 COUNT(*),           272457              FROM stg.appearances       UNION ALL
SELECT 'game_events',                 COUNT(*),           140607              FROM stg.game_events       UNION ALL
SELECT 'transfers',                   COUNT(*),           30643               FROM stg.transfers         UNION ALL
SELECT 'player_valuations',           COUNT(*),           96461               FROM stg.player_valuations;
