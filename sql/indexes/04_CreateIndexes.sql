-- =============================================================================
-- 04_CreateIndexes.sql  (RE-RUNNABLE / IDEMPOTENT)
-- All non-clustered indexes live on FG_Index for I/O separation.
-- Each index is created only if it does not already exist.
-- =============================================================================

USE [BruscaDb];
GO

-- ─── cleaning.Cleaning ───────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_cleaning_Cleaning_Status'
    AND object_id = OBJECT_ID(N'[cleaning].[Cleaning]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_cleaning_Cleaning_Status]
        ON [cleaning].[Cleaning]([Status] ASC)
        INCLUDE ([RootPath], [CreatedAtUtc])
        ON [FG_Index];
    PRINT 'Index IX_cleaning_Cleaning_Status created.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_cleaning_Cleaning_CreatedByUserId'
    AND object_id = OBJECT_ID(N'[cleaning].[Cleaning]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_cleaning_Cleaning_CreatedByUserId]
        ON [cleaning].[Cleaning]([CreatedByUserId] ASC)
        INCLUDE ([Status], [CreatedAtUtc])
        ON [FG_Index];
    PRINT 'Index IX_cleaning_Cleaning_CreatedByUserId created.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_cleaning_Cleaning_CreatedAtUtc'
    AND object_id = OBJECT_ID(N'[cleaning].[Cleaning]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_cleaning_Cleaning_CreatedAtUtc]
        ON [cleaning].[Cleaning]([CreatedAtUtc] DESC)
        ON [FG_Index];
    PRINT 'Index IX_cleaning_Cleaning_CreatedAtUtc created.';
END
GO

-- ─── cleaning.CleaningFileExtension ──────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_cleaning_CleaningFileExtension_CleaningId'
    AND object_id = OBJECT_ID(N'[cleaning].[CleaningFileExtension]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_cleaning_CleaningFileExtension_CleaningId]
        ON [cleaning].[CleaningFileExtension]([CleaningId] ASC)
        INCLUDE ([Extension], [Status], [FileCount])
        ON [FG_Index];
    PRINT 'Index IX_cleaning_CleaningFileExtension_CleaningId created.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_cleaning_CleaningFileExtension_Extension'
    AND object_id = OBJECT_ID(N'[cleaning].[CleaningFileExtension]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_cleaning_CleaningFileExtension_Extension]
        ON [cleaning].[CleaningFileExtension]([Extension] ASC)
        ON [FG_Index];
    PRINT 'Index IX_cleaning_CleaningFileExtension_Extension created.';
END
GO

-- ─── fileext.FileExtension ───────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_fileext_FileExtension_Status'
    AND object_id = OBJECT_ID(N'[fileext].[FileExtension]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_fileext_FileExtension_Status]
        ON [fileext].[FileExtension]([Status] ASC)
        INCLUDE ([Extension], [ReaderNuGetPackage])
        ON [FG_Index];
    PRINT 'Index IX_fileext_FileExtension_Status created.';
END
GO

-- ─── prompts.PromptStep ──────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_prompts_PromptStep_CleaningId_Order'
    AND object_id = OBJECT_ID(N'[prompts].[PromptStep]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_prompts_PromptStep_CleaningId_Order]
        ON [prompts].[PromptStep]([CleaningId] ASC, [StepOrder] ASC)
        INCLUDE ([StepType], [IsApproved], [IsExecuted])
        ON [FG_Index];
    PRINT 'Index IX_prompts_PromptStep_CleaningId_Order created.';
END
GO

-- ─── prompts.PromptStepCommand ───────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_prompts_PromptStepCommand_StepId_Order'
    AND object_id = OBJECT_ID(N'[prompts].[PromptStepCommand]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_prompts_PromptStepCommand_StepId_Order]
        ON [prompts].[PromptStepCommand]([PromptStepId] ASC, [CommandOrder] ASC)
        INCLUDE ([Language], [IsExecuted])
        ON [FG_Index];
    PRINT 'Index IX_prompts_PromptStepCommand_StepId_Order created.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_prompts_PromptStepCommand_IsExecuted'
    AND object_id = OBJECT_ID(N'[prompts].[PromptStepCommand]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_prompts_PromptStepCommand_IsExecuted]
        ON [prompts].[PromptStepCommand]([IsExecuted] ASC, [PromptStepId] ASC)
        ON [FG_Index];
    PRINT 'Index IX_prompts_PromptStepCommand_IsExecuted created.';
END
GO

-- ─── audit.Log ───────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_audit_Log_EntityType_EntityId'
    AND object_id = OBJECT_ID(N'[audit].[Log]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_audit_Log_EntityType_EntityId]
        ON [audit].[Log]([EntityType] ASC, [EntityId] ASC)
        INCLUDE ([EventType], [UserId], [CreatedAtUtc])
        ON [FG_Index];
    PRINT 'Index IX_audit_Log_EntityType_EntityId created.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_audit_Log_CreatedAtUtc'
    AND object_id = OBJECT_ID(N'[audit].[Log]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_audit_Log_CreatedAtUtc]
        ON [audit].[Log]([CreatedAtUtc] DESC)
        ON [FG_Index];
    PRINT 'Index IX_audit_Log_CreatedAtUtc created.';
END
GO

-- ─── error.Log ───────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_error_Log_Level_TimeStamp'
    AND object_id = OBJECT_ID(N'[error].[Log]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_error_Log_Level_TimeStamp]
        ON [error].[Log]([Level] ASC, [TimeStamp] DESC)
        ON [FG_Index];
    PRINT 'Index IX_error_Log_Level_TimeStamp created.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_error_Log_CorrelationId'
    AND object_id = OBJECT_ID(N'[error].[Log]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_error_Log_CorrelationId]
        ON [error].[Log]([CorrelationId] ASC)
        ON [FG_Index];
    PRINT 'Index IX_error_Log_CorrelationId created.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_error_Log_CleaningId'
    AND object_id = OBJECT_ID(N'[error].[Log]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_error_Log_CleaningId]
        ON [error].[Log]([CleaningId] ASC)
        WHERE [CleaningId] IS NOT NULL
        ON [FG_Index];
    PRINT 'Index IX_error_Log_CleaningId created.';
END
GO

-- ─── security.RefreshToken ───────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_security_RefreshToken_UserId'
    AND object_id = OBJECT_ID(N'[security].[RefreshToken]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_security_RefreshToken_UserId]
        ON [security].[RefreshToken]([UserId] ASC, [ExpiresAtUtc] DESC)
        WHERE [RevokedAtUtc] IS NULL
        ON [FG_Index];
    PRINT 'Index IX_security_RefreshToken_UserId created.';
END
GO

PRINT '04_CreateIndexes.sql complete.';
