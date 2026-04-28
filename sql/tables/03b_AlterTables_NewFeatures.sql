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

-- ─── cleaning.PathCredential (Phase 10 — path access & credentials) ─────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[cleaning].[PathCredential]') AND type = 'U')
BEGIN
    CREATE TABLE [cleaning].[PathCredential]
    (
        [Id]                UNIQUEIDENTIFIER NOT NULL,
        [CleaningId]        UNIQUEIDENTIFIER NOT NULL,
        [RootPath]          NVARCHAR(1024)   NOT NULL,
        [Username]          NVARCHAR(256)    NOT NULL,
        [EncryptedPassword] NVARCHAR(MAX)    NOT NULL,
        [Domain]            NVARCHAR(256)    NULL,
        [CreatedAtUtc]      DATETIME2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
        [LastUsedAtUtc]     DATETIME2(7)     NULL,
        CONSTRAINT [PK_cleaning_PathCredential] PRIMARY KEY CLUSTERED ([Id]),
        CONSTRAINT [FK_cleaning_PathCredential_Cleaning]
            FOREIGN KEY ([CleaningId]) REFERENCES [cleaning].[Cleaning]([Id]) ON DELETE CASCADE
    );
    CREATE UNIQUE INDEX [IX_cleaning_PathCredential_Cleaning_RootPath]
        ON [cleaning].[PathCredential] ([CleaningId], [RootPath]);
    PRINT 'Table [cleaning].[PathCredential] added.';
END
GO

-- ─── cleaning.RedactedFile.SlotMapJson (Phase 11 — per-file slot mapping) ────
IF OBJECT_ID(N'[cleaning].[RedactedFile]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns
       WHERE object_id = OBJECT_ID(N'[cleaning].[RedactedFile]') AND name = N'SlotMapJson')
BEGIN
    ALTER TABLE [cleaning].[RedactedFile] ADD [SlotMapJson] NVARCHAR(MAX) NULL;
    PRINT 'Column [cleaning].[RedactedFile].[SlotMapJson] added.';
END
GO

IF OBJECT_ID(N'[archive].[RedactedFile]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns
       WHERE object_id = OBJECT_ID(N'[archive].[RedactedFile]') AND name = N'SlotMapJson')
BEGIN
    ALTER TABLE [archive].[RedactedFile] ADD [SlotMapJson] NVARCHAR(MAX) NULL;
    PRINT 'Column [archive].[RedactedFile].[SlotMapJson] added.';
END
GO

PRINT '03b_AlterTables_NewFeatures.sql complete.';