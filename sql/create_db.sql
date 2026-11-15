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


