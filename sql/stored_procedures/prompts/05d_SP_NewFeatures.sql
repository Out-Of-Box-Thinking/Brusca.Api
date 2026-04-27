-- =============================================================================
-- 05d_SP_Cleaning_NewFeatures.sql
-- New stored procedures for restart, execution target, tree snapshots,
-- and PromptStepCommand CRUD.
-- =============================================================================

USE [BruscaDb];
GO

-- ─── cleaning.usp_Cleaning_Restart ───────────────────────────────────────────
-- Resets a Cleaning back to Pending and increments the restart counter.
-- Child steps and commands are deleted separately via their own SPs.
CREATE OR ALTER PROCEDURE [cleaning].[usp_Cleaning_Restart]
    @Id                  UNIQUEIDENTIFIER,
    @LastRestartedAtUtc  DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE [cleaning].[Cleaning]
    SET    [Status]              = 0,  -- Pending
           [RestartCount]        = [RestartCount] + 1,
           [LastRestartedAtUtc]  = @LastRestartedAtUtc,
           [CompletedAtUtc]      = NULL,
           [BeforeTreeJson]      = NULL,
           [AfterTreeJson]       = NULL
    WHERE  [Id] = @Id;
END;
GO

-- ─── cleaning.usp_Cleaning_SetExecutionTarget ─────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_Cleaning_SetExecutionTarget]
    @Id                    UNIQUEIDENTIFIER,
    @ExecutionTarget       TINYINT,
    @AlternateExecutionPath NVARCHAR(1024) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE [cleaning].[Cleaning]
    SET    [ExecutionTarget]        = @ExecutionTarget,
           [AlternateExecutionPath] = @AlternateExecutionPath
    WHERE  [Id] = @Id;
END;
GO

-- ─── cleaning.usp_Cleaning_SaveTreeSnapshots ─────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_Cleaning_SaveTreeSnapshots]
    @Id            UNIQUEIDENTIFIER,
    @BeforeTreeJson NVARCHAR(MAX) = NULL,
    @AfterTreeJson  NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE [cleaning].[Cleaning]
    SET    [BeforeTreeJson] = ISNULL(@BeforeTreeJson, [BeforeTreeJson]),
           [AfterTreeJson]  = @AfterTreeJson  -- NULL clears it intentionally on restart
    WHERE  [Id] = @Id;
END;
GO

-- ─── prompts.usp_PromptStep_DeleteByCleaningId ───────────────────────────────
-- Cascade-deletes PromptStepCommand rows first (FK ON DELETE CASCADE handles it),
-- then removes all steps for the Cleaning.
CREATE OR ALTER PROCEDURE [prompts].[usp_PromptStep_DeleteByCleaningId]
    @CleaningId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Commands are cascade-deleted via FK
    DELETE FROM [prompts].[PromptStep]
    WHERE  [CleaningId] = @CleaningId;
END;
GO

-- ─── prompts.usp_PromptStepCommand_Insert ────────────────────────────────────
CREATE OR ALTER PROCEDURE [prompts].[usp_PromptStepCommand_Insert]
    @Id           UNIQUEIDENTIFIER,
    @PromptStepId UNIQUEIDENTIFIER,
    @Language     TINYINT,
    @CommandBody  NVARCHAR(MAX),
    @CommandOrder INT,
    @CreatedAtUtc DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    INSERT INTO [prompts].[PromptStepCommand]
        ([Id], [PromptStepId], [Language], [CommandBody], [CommandOrder], [CreatedAtUtc])
    VALUES
        (@Id, @PromptStepId, @Language, @CommandBody, @CommandOrder, @CreatedAtUtc);

    SELECT [Id], [PromptStepId], [Language], [CommandBody], [CommandOrder],
           [IsExecuted], [ExecutedAtUtc], [ExecutionError], [CreatedAtUtc]
    FROM   [prompts].[PromptStepCommand]
    WHERE  [Id] = @Id;
END;
GO

-- ─── prompts.usp_PromptStepCommand_GetByStepId ───────────────────────────────
CREATE OR ALTER PROCEDURE [prompts].[usp_PromptStepCommand_GetByStepId]
    @PromptStepId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [Id], [PromptStepId], [Language], [CommandBody], [CommandOrder],
           [IsExecuted], [ExecutedAtUtc], [ExecutionError], [CreatedAtUtc]
    FROM   [prompts].[PromptStepCommand]
    WHERE  [PromptStepId] = @PromptStepId
    ORDER BY [CommandOrder] ASC;
END;
GO

-- ─── prompts.usp_PromptStepCommand_GetByCleaningId ───────────────────────────
-- Fetches all commands for a Cleaning in one round-trip (join through PromptStep).
CREATE OR ALTER PROCEDURE [prompts].[usp_PromptStepCommand_GetByCleaningId]
    @CleaningId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.[Id], c.[PromptStepId], c.[Language], c.[CommandBody], c.[CommandOrder],
           c.[IsExecuted], c.[ExecutedAtUtc], c.[ExecutionError], c.[CreatedAtUtc]
    FROM   [prompts].[PromptStepCommand] c
    JOIN   [prompts].[PromptStep]        s ON s.[Id] = c.[PromptStepId]
    WHERE  s.[CleaningId] = @CleaningId
    ORDER BY s.[StepOrder] ASC, c.[CommandOrder] ASC;
END;
GO

-- ─── prompts.usp_PromptStepCommand_MarkExecuted ──────────────────────────────
CREATE OR ALTER PROCEDURE [prompts].[usp_PromptStepCommand_MarkExecuted]
    @Id             UNIQUEIDENTIFIER,
    @ExecutedAtUtc  DATETIME2(7),
    @ExecutionError NVARCHAR(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [prompts].[PromptStepCommand]
    SET    [IsExecuted]    = 1,
           [ExecutedAtUtc] = @ExecutedAtUtc,
           [ExecutionError] = @ExecutionError
    WHERE  [Id] = @Id;
END;
GO

-- ─── prompts.usp_PromptStepCommand_DeleteByCleaningId ────────────────────────
-- Used during Restart to wipe commands before wiping steps.
CREATE OR ALTER PROCEDURE [prompts].[usp_PromptStepCommand_DeleteByCleaningId]
    @CleaningId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE c
    FROM   [prompts].[PromptStepCommand] c
    JOIN   [prompts].[PromptStep]        s ON s.[Id] = c.[PromptStepId]
    WHERE  s.[CleaningId] = @CleaningId;
END;
GO

PRINT '05d_SP_Cleaning_NewFeatures.sql applied.';
