-- =============================================================================
-- 01_CreateDatabase.sql  (RE-RUNNABLE / IDEMPOTENT)
-- Creates BruscaDb with split filegroups if it does not already exist.
-- Safe to re-run: skips creation if the database already exists.
--
-- Before running, create the data and log directories:
--   C:\SQLData\BruscaDb\
--   C:\SQLLog\BruscaDb\
-- Adjust paths to match your SQL Server instance if needed.
-- =============================================================================

USE [master];
GO

IF DB_ID(N'BruscaDb') IS NULL
BEGIN
    PRINT 'Creating BruscaDb...';

    CREATE DATABASE [BruscaDb]
    ON PRIMARY
    (
        NAME = N'BruscaDb_Primary',
        FILENAME = N'C:\SQLData\BruscaDb\BruscaDb_Primary.mdf',
        SIZE = 64MB, MAXSIZE = UNLIMITED, FILEGROWTH = 64MB
    ),
    FILEGROUP [FG_Data]
    (
        NAME = N'BruscaDb_Data',
        FILENAME = N'C:\SQLData\BruscaDb\BruscaDb_Data.ndf',
        SIZE = 128MB, MAXSIZE = UNLIMITED, FILEGROWTH = 128MB
    ),
    FILEGROUP [FG_Security]
    (
        NAME = N'BruscaDb_Security',
        FILENAME = N'C:\SQLData\BruscaDb\BruscaDb_Security.ndf',
        SIZE = 32MB, MAXSIZE = UNLIMITED, FILEGROWTH = 32MB
    ),
    FILEGROUP [FG_Audit]
    (
        NAME = N'BruscaDb_Audit',
        FILENAME = N'C:\SQLData\BruscaDb\BruscaDb_Audit.ndf',
        SIZE = 256MB, MAXSIZE = UNLIMITED, FILEGROWTH = 256MB
    ),
    FILEGROUP [FG_Error]
    (
        NAME = N'BruscaDb_Error',
        FILENAME = N'C:\SQLData\BruscaDb\BruscaDb_Error.ndf',
        SIZE = 128MB, MAXSIZE = UNLIMITED, FILEGROWTH = 128MB
    ),
    FILEGROUP [FG_Index]
    (
        NAME = N'BruscaDb_Index',
        FILENAME = N'C:\SQLData\BruscaDb\BruscaDb_Index.ndf',
        SIZE = 128MB, MAXSIZE = UNLIMITED, FILEGROWTH = 128MB
    )
    LOG ON
    (
        NAME = N'BruscaDb_Log',
        FILENAME = N'C:\SQLLog\BruscaDb\BruscaDb_Log.ldf',
        SIZE = 128MB, MAXSIZE = UNLIMITED, FILEGROWTH = 128MB
    );

    ALTER DATABASE [BruscaDb] SET RECOVERY FULL;
    ALTER DATABASE [BruscaDb] MODIFY FILEGROUP [FG_Data] DEFAULT;

    PRINT 'BruscaDb created successfully.';
END
ELSE
BEGIN
    PRINT 'BruscaDb already exists — skipping creation.';
END
GO

USE [BruscaDb];
GO
