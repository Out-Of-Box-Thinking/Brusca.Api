-- =============================================================================
-- 02_CreateSchemas.sql  (RE-RUNNABLE / IDEMPOTENT)
-- Creates all application schemas if they do not already exist.
-- =============================================================================

USE [BruscaDb];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'cleaning')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA [cleaning] AUTHORIZATION [dbo]';
    PRINT 'Schema [cleaning] created.';
END
ELSE PRINT 'Schema [cleaning] already exists.';
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'fileext')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA [fileext] AUTHORIZATION [dbo]';
    PRINT 'Schema [fileext] created.';
END
ELSE PRINT 'Schema [fileext] already exists.';
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'prompts')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA [prompts] AUTHORIZATION [dbo]';
    PRINT 'Schema [prompts] created.';
END
ELSE PRINT 'Schema [prompts] already exists.';
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'security')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA [security] AUTHORIZATION [dbo]';
    PRINT 'Schema [security] created.';
END
ELSE PRINT 'Schema [security] already exists.';
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'audit')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA [audit] AUTHORIZATION [dbo]';
    PRINT 'Schema [audit] created.';
END
ELSE PRINT 'Schema [audit] already exists.';
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'error')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA [error] AUTHORIZATION [dbo]';
    PRINT 'Schema [error] created.';
END
ELSE PRINT 'Schema [error] already exists.';
GO

PRINT '02_CreateSchemas.sql complete.';
