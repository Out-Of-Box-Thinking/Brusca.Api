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
GO

-- =============================================================================
-- PII PIPELINE — RedactedFile / StructurePlan / FileRelocation
-- =============================================================================

-- ─── cleaning.usp_RedactedFile_Insert ────────────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_RedactedFile_Insert]
    @Id               UNIQUEIDENTIFIER,
    @CleaningId       UNIQUEIDENTIFIER,
    @OriginalFilePath NVARCHAR(1024),
    @OriginalFileName NVARCHAR(512),
    @Extension        NVARCHAR(32),
    @DocumentType     INT,
    @RedactedContent  NVARCHAR(MAX) = NULL,
    @EncryptedPiiJson NVARCHAR(MAX) = NULL,
    @PiiSegmentCount  INT           = 0,
    @ContentHash      CHAR(64)      = NULL,
    @DiscoveredAtUtc  DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    INSERT INTO [cleaning].[RedactedFile]
        ([Id], [CleaningId], [OriginalFilePath], [OriginalFileName], [Extension],
         [DocumentType], [RedactedContent], [EncryptedPiiJson], [PiiSegmentCount],
         [ContentHash], [DiscoveredAtUtc])
    VALUES
        (@Id, @CleaningId, @OriginalFilePath, @OriginalFileName, LOWER(@Extension),
         @DocumentType, @RedactedContent, @EncryptedPiiJson, @PiiSegmentCount,
         @ContentHash, @DiscoveredAtUtc);
END;
GO

-- ─── cleaning.usp_RedactedFile_GetById ───────────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_RedactedFile_GetById]
    @Id UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [Id], [CleaningId], [OriginalFilePath], [OriginalFileName], [Extension],
           [DocumentType], [RedactedContent], [EncryptedPiiJson], [PiiSegmentCount],
           [ContentHash], [DiscoveredAtUtc]
    FROM   [cleaning].[RedactedFile]
    WHERE  [Id] = @Id;
END;
GO

-- ─── cleaning.usp_RedactedFile_GetByCleaningId ───────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_RedactedFile_GetByCleaningId]
    @CleaningId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [Id], [CleaningId], [OriginalFilePath], [OriginalFileName], [Extension],
           [DocumentType], [RedactedContent], [EncryptedPiiJson], [PiiSegmentCount],
           [ContentHash], [DiscoveredAtUtc]
    FROM   [cleaning].[RedactedFile]
    WHERE  [CleaningId] = @CleaningId
    ORDER BY [DiscoveredAtUtc] ASC;
END;
GO

-- ─── cleaning.usp_RedactedFile_GetDocumentTypeSummaries ──────────────────────
-- Anonymized aggregate fed to Claude — DocumentType + Extension + Count only.
CREATE OR ALTER PROCEDURE [cleaning].[usp_RedactedFile_GetDocumentTypeSummaries]
    @CleaningId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [DocumentType], [Extension], COUNT_BIG(*) AS [Count]
    FROM   [cleaning].[RedactedFile]
    WHERE  [CleaningId] = @CleaningId
    GROUP BY [DocumentType], [Extension]
    ORDER BY [DocumentType], [Extension];
END;
GO

-- ─── cleaning.usp_RedactedFile_DeleteByCleaningId ────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_RedactedFile_DeleteByCleaningId]
    @CleaningId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM [cleaning].[RedactedFile] WHERE [CleaningId] = @CleaningId;
END;
GO

-- ─── cleaning.usp_StructurePlan_Insert ───────────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_StructurePlan_Insert]
    @Id             UNIQUEIDENTIFIER,
    @CleaningId     UNIQUEIDENTIFIER,
    @Summary        NVARCHAR(2000) = NULL,
    @RulesJson      NVARCHAR(MAX),
    @RawPlanJson    NVARCHAR(MAX)  = NULL,
    @GeneratedAtUtc DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    INSERT INTO [cleaning].[StructurePlan]
        ([Id], [CleaningId], [Summary], [RulesJson], [RawPlanJson], [GeneratedAtUtc])
    VALUES
        (@Id, @CleaningId, @Summary, @RulesJson, @RawPlanJson, @GeneratedAtUtc);
END;
GO

-- ─── cleaning.usp_StructurePlan_GetLatest ────────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_StructurePlan_GetLatest]
    @CleaningId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
           [Id], [CleaningId], [Summary], [RulesJson], [RawPlanJson], [GeneratedAtUtc]
    FROM   [cleaning].[StructurePlan]
    WHERE  [CleaningId] = @CleaningId
    ORDER BY [GeneratedAtUtc] DESC;
END;
GO

-- ─── cleaning.usp_StructurePlan_DeleteByCleaningId ───────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_StructurePlan_DeleteByCleaningId]
    @CleaningId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM [cleaning].[StructurePlan] WHERE [CleaningId] = @CleaningId;
END;
GO

-- ─── cleaning.usp_FileRelocation_Insert ──────────────────────────────────────
-- Includes @ContentHashAfter for post-move SHA-256 integrity verification.
CREATE OR ALTER PROCEDURE [cleaning].[usp_FileRelocation_Insert]
    @Id               UNIQUEIDENTIFIER,
    @CleaningId       UNIQUEIDENTIFIER,
    @RedactedFileId   UNIQUEIDENTIFIER = NULL,
    @OperationType    INT,
    @ExecutionTarget  INT,
    @BeforePath       NVARCHAR(1024)  = NULL,
    @BeforeName       NVARCHAR(512)   = NULL,
    @AfterPath        NVARCHAR(1024)  = NULL,
    @AfterName        NVARCHAR(512)   = NULL,
    @Status           INT,
    @ErrorMessage     NVARCHAR(2000)  = NULL,
    @CreatedAtUtc     DATETIME2(7),
    @CompletedAtUtc   DATETIME2(7)    = NULL,
    @ContentHashAfter CHAR(64)        = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    INSERT INTO [cleaning].[FileRelocation]
        ([Id], [CleaningId], [RedactedFileId], [OperationType], [ExecutionTarget],
         [BeforePath], [BeforeName], [AfterPath], [AfterName],
         [Status], [ErrorMessage], [CreatedAtUtc], [CompletedAtUtc], [ContentHashAfter])
    VALUES
        (@Id, @CleaningId, @RedactedFileId, @OperationType, @ExecutionTarget,
         @BeforePath, @BeforeName, @AfterPath, @AfterName,
         @Status, @ErrorMessage, @CreatedAtUtc, @CompletedAtUtc, @ContentHashAfter);
END;
GO

-- ─── cleaning.usp_FileRelocation_UpdateStatus ────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_FileRelocation_UpdateStatus]
    @Id             UNIQUEIDENTIFIER,
    @Status         INT,
    @ErrorMessage   NVARCHAR(2000) = NULL,
    @CompletedAtUtc DATETIME2(7)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE [cleaning].[FileRelocation]
    SET    [Status]         = @Status,
           [ErrorMessage]   = @ErrorMessage,
           [CompletedAtUtc] = ISNULL(@CompletedAtUtc, [CompletedAtUtc])
    WHERE  [Id] = @Id;
END;
GO

-- ─── cleaning.usp_FileRelocation_GetByCleaningId ─────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_FileRelocation_GetByCleaningId]
    @CleaningId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [Id], [CleaningId], [RedactedFileId], [OperationType], [ExecutionTarget],
           [BeforePath], [BeforeName], [AfterPath], [AfterName],
           [Status], [ErrorMessage], [CreatedAtUtc], [CompletedAtUtc], [ContentHashAfter]
    FROM   [cleaning].[FileRelocation]
    WHERE  [CleaningId] = @CleaningId
    ORDER BY [CreatedAtUtc] ASC;
END;
GO

PRINT 'PII pipeline stored procedures created.';

-- =============================================================================
-- COWORK-PARITY ADDITIONS — slot catalog, dedupe, promotion, plan-update
-- =============================================================================

-- ─── cleaning.usp_RedactedFilePiiKind_Insert ─────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_RedactedFilePiiKind_Insert]
    @RedactedFileId UNIQUEIDENTIFIER,
    @PiiKind        INT,
    @Count          INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    INSERT INTO [cleaning].[RedactedFilePiiKind]
        ([Id], [RedactedFileId], [PiiKind], [Count], [CreatedAtUtc])
    VALUES
        (NEWID(), @RedactedFileId, @PiiKind, @Count, SYSUTCDATETIME());
END;
GO

-- ─── cleaning.usp_RedactedFile_GetSlotCatalog ────────────────────────────────
-- Returns one row per (DocumentType, PiiKind) pair observed for the cleaning.
-- The host groups by DocumentType to build the per-type slot vocabulary.
CREATE OR ALTER PROCEDURE [cleaning].[usp_RedactedFile_GetSlotCatalog]
    @CleaningId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT f.[DocumentType], k.[PiiKind]
    FROM   [cleaning].[RedactedFile]        f
    JOIN   [cleaning].[RedactedFilePiiKind] k ON k.[RedactedFileId] = f.[Id]
    WHERE  f.[CleaningId] = @CleaningId
    ORDER BY f.[DocumentType], k.[PiiKind];
END;
GO

-- ─── cleaning.usp_RedactedFile_GetDuplicateGroups ────────────────────────────
-- Two result sets:
--   1) (ContentHash, KeepRedactedFileId)  -- one row per duplicate group;
--      keeper is the alphabetically-first OriginalFilePath (KeepFirstPath).
--   2) (ContentHash, RedactedFileId)      -- every member of every group.
CREATE OR ALTER PROCEDURE [cleaning].[usp_RedactedFile_GetDuplicateGroups]
    @CleaningId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH dups AS (
        SELECT [ContentHash]
        FROM   [cleaning].[RedactedFile]
        WHERE  [CleaningId] = @CleaningId
          AND  [ContentHash] IS NOT NULL
        GROUP BY [ContentHash]
        HAVING COUNT_BIG(*) > 1
    ),
    ranked AS (
        SELECT f.[ContentHash], f.[Id] AS [RedactedFileId], f.[OriginalFilePath],
               ROW_NUMBER() OVER (PARTITION BY f.[ContentHash]
                                  ORDER BY f.[OriginalFilePath]) AS [rn]
        FROM   [cleaning].[RedactedFile] f
        JOIN   dups d ON d.[ContentHash] = f.[ContentHash]
        WHERE  f.[CleaningId] = @CleaningId
    )
    SELECT [ContentHash], [RedactedFileId] AS [KeepRedactedFileId]
    FROM   ranked
    WHERE  [rn] = 1
    ORDER BY [ContentHash];

    SELECT f.[ContentHash], f.[Id] AS [RedactedFileId]
    FROM   [cleaning].[RedactedFile] f
    JOIN   (SELECT [ContentHash] FROM [cleaning].[RedactedFile]
            WHERE [CleaningId] = @CleaningId AND [ContentHash] IS NOT NULL
            GROUP BY [ContentHash] HAVING COUNT_BIG(*) > 1) d
        ON d.[ContentHash] = f.[ContentHash]
    WHERE  f.[CleaningId] = @CleaningId
    ORDER BY f.[ContentHash], f.[OriginalFilePath];
END;
GO

-- ─── cleaning.usp_FileRelocation_GetById ─────────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_FileRelocation_GetById]
    @Id UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [Id], [CleaningId], [RedactedFileId], [OperationType], [ExecutionTarget],
           [BeforePath], [BeforeName], [AfterPath], [AfterName],
           [Status], [ErrorMessage], [CreatedAtUtc], [CompletedAtUtc], [ContentHashAfter]
    FROM   [cleaning].[FileRelocation]
    WHERE  [Id] = @Id;
END;
GO

-- ─── cleaning.usp_FileRelocation_UpdateAfter ─────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_FileRelocation_UpdateAfter]
    @Id               UNIQUEIDENTIFIER,
    @AfterPath        NVARCHAR(1024) = NULL,
    @AfterName        NVARCHAR(512)  = NULL,
    @Status           INT,
    @ErrorMessage     NVARCHAR(2000) = NULL,
    @ContentHashAfter CHAR(64)       = NULL,
    @CompletedAtUtc   DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE [cleaning].[FileRelocation]
    SET    [AfterPath]        = @AfterPath,
           [AfterName]        = @AfterName,
           [Status]           = @Status,
           [ErrorMessage]     = @ErrorMessage,
           [ContentHashAfter] = @ContentHashAfter,
           [CompletedAtUtc]   = @CompletedAtUtc
    WHERE  [Id] = @Id;
END;
GO

-- ─── cleaning.usp_PromotionRecord_Insert ─────────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_PromotionRecord_Insert]
    @Id               UNIQUEIDENTIFIER,
    @CleaningId       UNIQUEIDENTIFIER,
    @FileRelocationId UNIQUEIDENTIFIER,
    @OriginalPath     NVARCHAR(1024),
    @Status           INT,
    @ErrorMessage     NVARCHAR(2000) = NULL,
    @VerifiedAtUtc    DATETIME2(7)   = NULL,
    @PromotedAtUtc    DATETIME2(7)   = NULL,
    @CreatedAtUtc     DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    INSERT INTO [cleaning].[PromotionRecord]
        ([Id], [CleaningId], [FileRelocationId], [OriginalPath], [Status],
         [ErrorMessage], [VerifiedAtUtc], [PromotedAtUtc], [CreatedAtUtc])
    VALUES
        (@Id, @CleaningId, @FileRelocationId, @OriginalPath, @Status,
         @ErrorMessage, @VerifiedAtUtc, @PromotedAtUtc, @CreatedAtUtc);
END;
GO

-- ─── cleaning.usp_PromotionRecord_UpdateStatus ───────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_PromotionRecord_UpdateStatus]
    @Id            UNIQUEIDENTIFIER,
    @Status        INT,
    @ErrorMessage  NVARCHAR(2000) = NULL,
    @VerifiedAtUtc DATETIME2(7)   = NULL,
    @PromotedAtUtc DATETIME2(7)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE [cleaning].[PromotionRecord]
    SET    [Status]        = @Status,
           [ErrorMessage]  = @ErrorMessage,
           [VerifiedAtUtc] = @VerifiedAtUtc,
           [PromotedAtUtc] = @PromotedAtUtc
    WHERE  [Id] = @Id;
END;
GO

-- ─── cleaning.usp_PromotionRecord_GetByCleaningId ────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_PromotionRecord_GetByCleaningId]
    @CleaningId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [Id], [CleaningId], [FileRelocationId], [OriginalPath], [Status],
           [ErrorMessage], [VerifiedAtUtc], [PromotedAtUtc], [CreatedAtUtc]
    FROM   [cleaning].[PromotionRecord]
    WHERE  [CleaningId] = @CleaningId
    ORDER BY [CreatedAtUtc] ASC;
END;
GO

PRINT 'Cowork-parity stored procedures created.';
GO
