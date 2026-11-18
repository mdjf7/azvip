USE FudbalDB;
GO

IF OBJECT_ID('dbo.fact_valuation', 'U') IS NOT NULL DROP TABLE dbo.fact_valuation;
IF OBJECT_ID('dbo.fact_transfer', 'U') IS NOT NULL DROP TABLE dbo.fact_transfer;
IF OBJECT_ID('dbo.fact_appearance', 'U') IS NOT NULL DROP TABLE dbo.fact_appearance;
IF OBJECT_ID('dbo.fact_club_match', 'U') IS NOT NULL DROP TABLE dbo.fact_club_match;
IF OBJECT_ID('dbo.dim_player', 'U') IS NOT NULL DROP TABLE dbo.dim_player;
IF OBJECT_ID('dbo.dim_club', 'U') IS NOT NULL DROP TABLE dbo.dim_club;
IF OBJECT_ID('dbo.dim_competition', 'U') IS NOT NULL DROP TABLE dbo.dim_competition;
IF OBJECT_ID('dbo.dim_date', 'U') IS NOT NULL DROP TABLE dbo.dim_date;
GO

CREATE TABLE dbo.dim_date (
    date_key        INT            NOT NULL PRIMARY KEY,
    [date]          DATE           NOT NULL,
    [year]          INT            NOT NULL,
    [quarter]       INT            NOT NULL,
    [month]         INT            NOT NULL,
    month_name      NVARCHAR(20)   NOT NULL,
    season          INT            NOT NULL,
    season_label    NVARCHAR(10)   NOT NULL,
    season_half     NVARCHAR(10)   NOT NULL
);
GO

CREATE TABLE dbo.dim_competition (
    competition_id  NVARCHAR(30)   NOT NULL PRIMARY KEY,
    name            NVARCHAR(100)  NULL,
    country_name    NVARCHAR(100)  NULL,
    type            NVARCHAR(30)   NULL
);
GO

CREATE TABLE dbo.dim_club (
    club_id         INT            NOT NULL PRIMARY KEY,
    name            NVARCHAR(100)  NULL,
    competition_id  NVARCHAR(30)   NULL REFERENCES dbo.dim_competition(competition_id),
    stadium_name    NVARCHAR(100)  NULL,
    stadium_seats   INT            NULL,
    is_top5         BIT            NOT NULL
);
GO

CREATE TABLE dbo.dim_player (
    player_id               INT            NOT NULL PRIMARY KEY,
    name                    NVARCHAR(100)  NULL,
    country_of_citizenship  NVARCHAR(100)  NULL,
    position                NVARCHAR(50)   NULL,
    sub_position            NVARCHAR(50)   NULL,
    foot                    NVARCHAR(30)   NULL,
    height_in_cm            INT            NULL,
    date_of_birth           DATE           NULL
);
GO

CREATE TABLE dbo.fact_club_match (
    game_id         INT            NOT NULL,
    club_id         INT            NOT NULL REFERENCES dbo.dim_club(club_id),
    opponent_id     INT            NOT NULL REFERENCES dbo.dim_club(club_id),
    date_key        INT            NOT NULL REFERENCES dbo.dim_date(date_key),
    competition_id  NVARCHAR(30)   NOT NULL REFERENCES dbo.dim_competition(competition_id),
    season          INT            NOT NULL,
    matchday        INT            NULL,
    is_home         BIT            NOT NULL,
    goals_for       INT            NULL,
    goals_against   INT            NULL,
    points          INT            NULL,
    result          CHAR(1)        NULL,
    manager_name    NVARCHAR(100)  NULL,
    attendance      INT            NULL,
    CONSTRAINT pk_fact_club_match PRIMARY KEY (game_id, club_id)
);
GO

CREATE TABLE dbo.fact_appearance (
    appearance_id   VARCHAR(40)    NOT NULL PRIMARY KEY,
    game_id         INT            NOT NULL,
    date_key        INT            NOT NULL REFERENCES dbo.dim_date(date_key),
    player_id       INT            NOT NULL REFERENCES dbo.dim_player(player_id),
    club_id         INT            NOT NULL REFERENCES dbo.dim_club(club_id),
    competition_id  NVARCHAR(30)   NOT NULL REFERENCES dbo.dim_competition(competition_id),
    minutes_played  INT            NULL,
    goals           INT            NULL,
    assists         INT            NULL,
    yellow_cards    INT            NULL,
    red_cards       INT            NULL
);
GO

CREATE TABLE dbo.fact_transfer (
    transfer_id          INT IDENTITY(1,1) PRIMARY KEY,
    player_id            INT            NOT NULL REFERENCES dbo.dim_player(player_id),
    date_key             INT            NOT NULL REFERENCES dbo.dim_date(date_key),
    transfer_season      NVARCHAR(30)   NULL,
    from_club_id         INT            NOT NULL REFERENCES dbo.dim_club(club_id),
    to_club_id           INT            NOT NULL REFERENCES dbo.dim_club(club_id),
    transfer_fee         BIGINT         NULL,
    market_value_in_eur  BIGINT         NULL
);
GO

CREATE TABLE dbo.fact_valuation (
    player_id            INT            NOT NULL REFERENCES dbo.dim_player(player_id),
    date_key             INT            NOT NULL REFERENCES dbo.dim_date(date_key),
    club_id              INT            NULL REFERENCES dbo.dim_club(club_id),
    market_value_in_eur  BIGINT         NOT NULL,
    CONSTRAINT pk_fact_valuation PRIMARY KEY (player_id, date_key)
);
GO
