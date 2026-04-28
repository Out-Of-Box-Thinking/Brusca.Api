-- =============================================================================
-- 03b_AlterTables_NewFeatures.sql  (MERGED INTO 03_CreateTables.sql)
-- The v2 columns (RestartCount, ExecutionTarget, BeforeTreeJson, AfterTreeJson,
-- AlternateExecutionPath, LastRestartedAtUtc) and the PromptStepCommand table
-- are now included directly in 03_CreateTables.sql.
--
-- This file adds the columns only if they are missing, for databases that were
-- created from an older version of 03_CreateTables.sql.
-- =============================================================================

USE [BruscaDb];
GO

-- RestartCount
IF NOT EXISTS (SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[cleaning].[Cleaning]') AND name = N'RestartCount')
BEGIN
    ALTER TABLE [cleaning].[Cleaning] ADD [RestartCount] INT NOT NULL DEFAULT 0;
    PRINT 'Column RestartCount added.';
END
GO

-- LastRestartedAtUtc
IF NOT EXISTS (SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[cleaning].[Cleaning]') AND name = N'LastRestartedAtUtc')
BEGIN
    ALTER TABLE [cleaning].[Cleaning] ADD [LastRestartedAtUtc] DATETIME2(7) NULL;
    PRINT 'Column LastRestartedAtUtc added.';
END
GO

-- ExecutionTarget
IF NOT EXISTS (SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[cleaning].[Cleaning]') AND name = N'ExecutionTarget')
BEGIN
    ALTER TABLE [cleaning].[Cleaning] ADD [ExecutionTarget] TINYINT NOT NULL DEFAULT 0;
    PRINT 'Column ExecutionTarget added.';
END
GO

-- AlternateExecutionPath
IF NOT EXISTS (SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[cleaning].[Cleaning]') AND name = N'AlternateExecutionPath')
BEGIN
    ALTER TABLE [cleaning].[Cleaning] ADD [AlternateExecutionPath] NVARCHAR(1024) NULL;
    PRINT 'Column AlternateExecutionPath added.';
END
GO

-- BeforeTreeJson
IF NOT EXISTS (SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[cleaning].[Cleaning]') AND name = N'BeforeTreeJson')
BEGIN
    ALTER TABLE [cleaning].[Cleaning] ADD [BeforeTreeJson] NVARCHAR(MAX) NULL;
    PRINT 'Column BeforeTreeJson added.';
END
GO

-- AfterTreeJson
IF NOT EXISTS (SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[cleaning].[Cleaning]') AND name = N'AfterTreeJson')
BEGIN
    ALTER TABLE [cleaning].[Cleaning] ADD [AfterTreeJson] NVARCHAR(MAX) NULL;
    PRINT 'Column AfterTreeJson added.';
END
GO

-- ─── PII pipeline column patches (apply only if older table shape) ───────────

-- cleaning.FileRelocation.ContentHashAfter (added in PII rollout)
IF OBJECT_ID(N'[cleaning].[FileRelocation]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns
       WHERE object_id = OBJECT_ID(N'[cleaning].[FileRelocation]') AND name = N'ContentHashAfter')
BEGIN
    ALTER TABLE [cleaning].[FileRelocation] ADD [ContentHashAfter] CHAR(64) NULL;
    PRINT 'Column [cleaning].[FileRelocation].[ContentHashAfter] added.';
END
GO

-- archive.FileRelocation.ContentHashAfter
IF OBJECT_ID(N'[archive].[FileRelocation]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns
       WHERE object_id = OBJECT_ID(N'[archive].[FileRelocation]') AND name = N'ContentHashAfter')
BEGIN
    ALTER TABLE [archive].[FileRelocation] ADD [ContentHashAfter] CHAR(64) NULL;
    PRINT 'Column [archive].[FileRelocation].[ContentHashAfter] added.';
END
GO

-- cleaning.RedactedFile.ContentHash (older shape may have lacked it)
IF OBJECT_ID(N'[cleaning].[RedactedFile]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns
       WHERE object_id = OBJECT_ID(N'[cleaning].[RedactedFile]') AND name = N'ContentHash')
BEGIN
    ALTER TABLE [cleaning].[RedactedFile] ADD [ContentHash] CHAR(64) NULL;
    PRINT 'Column [cleaning].[RedactedFile].[ContentHash] added.';
END
GO

-- cleaning.RedactedFile.ImageRedactionRegionsJson (Phase 9 — image sanitization)
IF OBJECT_ID(N'[cleaning].[RedactedFile]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns
       WHERE object_id = OBJECT_ID(N'[cleaning].[RedactedFile]') AND name = N'ImageRedactionRegionsJson')
BEGIN
    ALTER TABLE [cleaning].[RedactedFile] ADD [ImageRedactionRegionsJson] NVARCHAR(MAX) NULL;
    PRINT 'Column [cleaning].[RedactedFile].[ImageRedactionRegionsJson] added.';
END
GO

-- archive.RedactedFile.ImageRedactionRegionsJson
IF OBJECT_ID(N'[archive].[RedactedFile]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns
       WHERE object_id = OBJECT_ID(N'[archive].[RedactedFile]') AND name = N'ImageRedactionRegionsJson')
BEGIN
    ALTER TABLE [archive].[RedactedFile] ADD [ImageRedactionRegionsJson] NVARCHAR(MAX) NULL;
    PRINT 'Column [archive].[RedactedFile].[ImageRedactionRegionsJson] added.';
END
GO

PRINT '03b_AlterTables_NewFeatures.sql complete.';
