USE master;
GO
IF DB_ID('FudbalDB') IS NOT NULL
BEGIN
    ALTER DATABASE FudbalDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE FudbalDB;
END
GO
CREATE DATABASE FudbalDB;
GO
ALTER DATABASE FudbalDB SET COMPATIBILITY_LEVEL = 150;   
GO
USE FudbalDB;
GO
CREATE SCHEMA stg;  
GO

 

CREATE TABLE stg.competitions (
    competition_id        NVARCHAR(30),
    competition_code      NVARCHAR(100),
    name                  NVARCHAR(100),
    sub_type              NVARCHAR(30),
    type                  NVARCHAR(30),
    country_id            INT,
    country_name          NVARCHAR(100),
    domestic_league_code  NVARCHAR(30),
    confederation         NVARCHAR(30),
    total_clubs           INT
);
GO


CREATE TABLE stg.clubs (
    club_id               INT,
    club_code             NVARCHAR(100),
    name                  NVARCHAR(100),
    domestic_competition_id             NVARCHAR(30),
    total_market_value                  BIGINT,
    squad_size            INT,
    average_age          DECIMAL(5,2),
    foreigners_number  INT,
    foreigners_percentage         DECIMAL(5,2),
    national_team_players           INT,
    stadium_name        NVARCHAR(100),
    stadium_seats           INT,
    net_transfer_record NVARCHAR(400),
    coach_name      NVARCHAR(100),
    last_season     INT
);
GO


CREATE TABLE stg.players (
    player_id                             INT,
    first_name                            NVARCHAR(100),
    last_name                             NVARCHAR(100),
    name                                  NVARCHAR(100),
    last_season                           INT,
    current_club_id                       INT,
    player_code                           NVARCHAR(100),
    country_of_birth                      NVARCHAR(100),
    city_of_birth                         NVARCHAR(100),
    country_of_citizenship                NVARCHAR(100),
    date_of_birth                         DATE,
    sub_position                          NVARCHAR(50),
    position                              NVARCHAR(50),
    foot                                  NVARCHAR(30),
    height_in_cm                          INT,
    contract_expiration_date              DATE,
    agent_name                            NVARCHAR(200),
    international_caps                    INT,
    international_goals                   INT,
    current_national_team_id              INT,
    current_club_domestic_competition_id  NVARCHAR(30),
    current_club_name                     NVARCHAR(100),
    market_value_in_eur                   BIGINT,
    highest_market_value_in_eur           BIGINT
);
GO

 
CREATE TABLE stg.games (
    game_id                  INT,
    competition_id           NVARCHAR(30),
    season                   INT,              
    round                    NVARCHAR(50),     
    date                     DATE,
    home_club_id             INT,
    away_club_id             INT,
    home_club_goals          INT,
    away_club_goals          INT,
    home_club_position       INT,
    away_club_position       INT,
    home_club_manager_name   NVARCHAR(100),
    away_club_manager_name   NVARCHAR(100),
    stadium                  NVARCHAR(100),
    attendance               INT,
    referee                  NVARCHAR(100),
    home_club_formation      NVARCHAR(50),    
    away_club_formation      NVARCHAR(50),
    home_club_name           NVARCHAR(100),
    away_club_name           NVARCHAR(100),
    aggregate                NVARCHAR(30),    
    competition_type         NVARCHAR(30)
);
GO

 
CREATE TABLE stg.club_games (
    game_id                  INT,
    club_id                  INT,
    own_goals                INT,
    own_position             INT,
    own_manager_name         NVARCHAR(100),
    opponent_id              INT,
    opponent_goals           INT,
    opponent_position        INT,
    opponent_manager_name    NVARCHAR(100),
    hosting                  NVARCHAR(30),     
    is_win                   BIT
);
GO
 
CREATE TABLE stg.appearances (
    appearance_id            VARCHAR(40),      
    game_id                  INT,
    player_id                INT,
    player_club_id           INT,
    player_current_club_id   INT,
    date                     DATE,
    player_name              NVARCHAR(100),
    competition_id           NVARCHAR(30),
    yellow_cards             INT,
    red_cards                INT,
    goals                    INT,
    assists                  INT,
    minutes_played           INT
);
GO
 
CREATE TABLE stg.game_events (
    game_event_id            VARCHAR(40),      
    date                     DATE,
    game_id                  INT,
    minute                   INT,
    type                     NVARCHAR(30),     
    club_id                  INT,
    club_name                NVARCHAR(100),
    player_id                INT,
    description              NVARCHAR(1000),
    player_in_id             INT,
    player_assist_id         INT
);
GO

 
CREATE TABLE stg.transfers (
    player_id                INT,
    transfer_date            DATE,
    transfer_season          NVARCHAR(30),     
    from_club_id             INT,
    to_club_id               INT,
    from_club_name           NVARCHAR(100),
    to_club_name             NVARCHAR(100),
    transfer_fee             BIGINT,           
    market_value_in_eur      BIGINT,
    player_name              NVARCHAR(100)
);
GO
 
CREATE TABLE stg.player_valuations (
    player_id                            INT,
    date                                 DATE,
    market_value_in_eur                  BIGINT,
    current_club_name                    NVARCHAR(100),
    current_club_id                      INT,
    player_club_domestic_competition_id  NVARCHAR(30)
);
GO

 