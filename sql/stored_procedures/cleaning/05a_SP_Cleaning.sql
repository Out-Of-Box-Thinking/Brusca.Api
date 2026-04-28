-- =============================================================================
-- 05_StoredProcedures_Cleaning.sql
-- Stored procedure naming convention: schema.usp_Entity_Action
-- =============================================================================

USE [BruscaDb];
GO

-- ─── cleaning.usp_Cleaning_Create ────────────────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_Cleaning_Create]
    @Id              UNIQUEIDENTIFIER,
    @RootPath        NVARCHAR(1024),
    @CreatedByUserId NVARCHAR(256),
    @Notes           NVARCHAR(2000) = NULL,
    @CreatedAtUtc    DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    INSERT INTO [cleaning].[Cleaning]
        ([Id], [RootPath], [Status], [CreatedByUserId], [Notes], [CreatedAtUtc])
    VALUES
        (@Id, @RootPath, 0, @CreatedByUserId, @Notes, @CreatedAtUtc);

    SELECT [Id], [RootPath], [Status], [CreatedByUserId], [Notes],
           [CreatedAtUtc], [CompletedAtUtc]
    FROM   [cleaning].[Cleaning]
    WHERE  [Id] = @Id;
END;
GO

-- ─── cleaning.usp_Cleaning_GetById ───────────────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_Cleaning_GetById]
    @Id UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.[Id], c.[RootPath], c.[Status], c.[CreatedByUserId], c.[Notes],
           c.[CreatedAtUtc], c.[CompletedAtUtc]
    FROM   [cleaning].[Cleaning] c
    WHERE  c.[Id] = @Id;

    SELECT e.[Id], e.[CleaningId], e.[ExtensionId], e.[Extension],
           e.[FileCount], e.[Status], e.[SuggestedNuGetPackage], e.[DiscoveredAtUtc]
    FROM   [cleaning].[CleaningFileExtension] e
    WHERE  e.[CleaningId] = @Id;
END;
GO

-- ─── cleaning.usp_Cleaning_GetPaged ──────────────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_Cleaning_GetPaged]
    @Page     INT = 1,
    @PageSize INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [Id], [RootPath], [Status], [CreatedByUserId], [Notes],
           [CreatedAtUtc], [CompletedAtUtc]
    FROM   [cleaning].[Cleaning]
    ORDER BY [CreatedAtUtc] DESC
    OFFSET  (@Page - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- ─── cleaning.usp_Cleaning_UpdateStatus ──────────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_Cleaning_UpdateStatus]
    @Id     UNIQUEIDENTIFIER,
    @Status TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE [cleaning].[Cleaning]
    SET    [Status] = @Status
    WHERE  [Id] = @Id;
END;
GO

-- ─── cleaning.usp_Cleaning_Complete ──────────────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_Cleaning_Complete]
    @Id             UNIQUEIDENTIFIER,
    @CompletedAtUtc DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE [cleaning].[Cleaning]
    SET    [Status]         = 6,  -- Completed
           [CompletedAtUtc] = @CompletedAtUtc
    WHERE  [Id] = @Id;
END;
GO

-- ─── cleaning.usp_CleaningFileExtension_Insert ───────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_CleaningFileExtension_Insert]
    @Id                    UNIQUEIDENTIFIER,
    @CleaningId            UNIQUEIDENTIFIER,
    @ExtensionId           UNIQUEIDENTIFIER,
    @Extension             NVARCHAR(50),
    @FileCount             INT = 0,
    @Status                TINYINT = 1,
    @SuggestedNuGetPackage NVARCHAR(512) = NULL,
    @DiscoveredAtUtc       DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    INSERT INTO [cleaning].[CleaningFileExtension]
        ([Id], [CleaningId], [ExtensionId], [Extension],
         [FileCount], [Status], [SuggestedNuGetPackage], [DiscoveredAtUtc])
    VALUES
        (@Id, @CleaningId, @ExtensionId, LOWER(@Extension),
         @FileCount, @Status, @SuggestedNuGetPackage, @DiscoveredAtUtc);
END;
GO

PRINT 'cleaning stored procedures created.';
GO

-- ─── cleaning.usp_Cleaning_GetActive ─────────────────────────────────────────
-- Returns the single non-terminal Cleaning, or no rows if none is active.
-- Terminal statuses (Completed=6, Failed=7, Cancelled=8, Archived=14) are excluded.
CREATE OR ALTER PROCEDURE [cleaning].[usp_Cleaning_GetActive]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
           [Id], [RootPath], [Status], [CreatedByUserId], [Notes],
           [CreatedAtUtc], [CompletedAtUtc],
           [RestartCount], [LastRestartedAtUtc],
           [ExecutionTarget], [AlternateExecutionPath],
           [BeforeTreeJson], [AfterTreeJson]
    FROM   [cleaning].[Cleaning]
    WHERE  [Status] NOT IN (6, 7, 8, 14)
    ORDER BY [CreatedAtUtc] DESC;
END;
GO

-- ─── cleaning.usp_Cleaning_Archive ───────────────────────────────────────────
-- Transactionally moves a Cleaning and every dependent row from the working
-- cleaning.* schema into the archive.* schema, sets Status = 14 (Archived),
-- stamps ArchivedAtUtc, and deletes the originals in dependency order.
CREATE OR ALTER PROCEDURE [cleaning].[usp_Cleaning_Archive]
    @Id            UNIQUEIDENTIFIER,
    @ArchivedAtUtc DATETIME2(7) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @stamp DATETIME2(7) = ISNULL(@ArchivedAtUtc, SYSUTCDATETIME());

    BEGIN TRAN;

    -- Stamp the working row to Archived before mirroring so the archive copy
    -- reflects the terminal state.
    UPDATE [cleaning].[Cleaning] SET [Status] = 14 WHERE [Id] = @Id;

    -- 1. Mirror the parent row.
    INSERT INTO [archive].[Cleaning]
        ([Id], [RootPath], [Status], [CreatedByUserId], [Notes],
         [CreatedAtUtc], [CompletedAtUtc], [RestartCount], [LastRestartedAtUtc],
         [ExecutionTarget], [AlternateExecutionPath],
         [BeforeTreeJson], [AfterTreeJson], [ArchivedAtUtc])
    SELECT [Id], [RootPath], [Status], [CreatedByUserId], [Notes],
           [CreatedAtUtc], [CompletedAtUtc], [RestartCount], [LastRestartedAtUtc],
           [ExecutionTarget], [AlternateExecutionPath],
           [BeforeTreeJson], [AfterTreeJson], @stamp
    FROM   [cleaning].[Cleaning]
    WHERE  [Id] = @Id;

    -- 2. Mirror dependents.
    INSERT INTO [archive].[CleaningFileExtension]
        ([Id], [CleaningId], [ExtensionId], [Extension], [FileCount],
         [Status], [SuggestedNuGetPackage], [DiscoveredAtUtc], [ArchivedAtUtc])
    SELECT [Id], [CleaningId], [ExtensionId], [Extension], [FileCount],
           [Status], [SuggestedNuGetPackage], [DiscoveredAtUtc], @stamp
    FROM   [cleaning].[CleaningFileExtension]
    WHERE  [CleaningId] = @Id;

    INSERT INTO [archive].[PromptStepCommand]
        ([Id], [PromptStepId], [Language], [CommandBody], [CommandOrder],
         [IsExecuted], [ExecutedAtUtc], [ExecutionError], [CreatedAtUtc], [ArchivedAtUtc])
    SELECT c.[Id], c.[PromptStepId], c.[Language], c.[CommandBody], c.[CommandOrder],
           c.[IsExecuted], c.[ExecutedAtUtc], c.[ExecutionError], c.[CreatedAtUtc], @stamp
    FROM   [prompts].[PromptStepCommand] c
    JOIN   [prompts].[PromptStep]        s ON s.[Id] = c.[PromptStepId]
    WHERE  s.[CleaningId] = @Id;

    INSERT INTO [archive].[PromptStep]
        ([Id], [CleaningId], [StepOrder], [StepType], [PromptText],
         [GeneratedResponse], [SourcePath], [ProposedTargetPath],
         [IsApproved], [IsExecuted], [CreatedAtUtc], [ExecutedAtUtc],
         [ExecutionError], [ArchivedAtUtc])
    SELECT [Id], [CleaningId], [StepOrder], [StepType], [PromptText],
           [GeneratedResponse], [SourcePath], [ProposedTargetPath],
           [IsApproved], [IsExecuted], [CreatedAtUtc], [ExecutedAtUtc],
           [ExecutionError], @stamp
    FROM   [prompts].[PromptStep]
    WHERE  [CleaningId] = @Id;

    IF OBJECT_ID(N'[cleaning].[FileRelocation]', N'U') IS NOT NULL
    BEGIN
        INSERT INTO [archive].[FileRelocation]
            ([Id], [CleaningId], [RedactedFileId], [OperationType], [ExecutionTarget],
             [BeforePath], [BeforeName], [AfterPath], [AfterName], [Status],
             [ErrorMessage], [CreatedAtUtc], [CompletedAtUtc], [ContentHashAfter], [ArchivedAtUtc])
        SELECT [Id], [CleaningId], [RedactedFileId], [OperationType], [ExecutionTarget],
               [BeforePath], [BeforeName], [AfterPath], [AfterName], [Status],
               [ErrorMessage], [CreatedAtUtc], [CompletedAtUtc], [ContentHashAfter], @stamp
        FROM   [cleaning].[FileRelocation]
        WHERE  [CleaningId] = @Id;
    END;

    IF OBJECT_ID(N'[cleaning].[StructurePlan]', N'U') IS NOT NULL
    BEGIN
        INSERT INTO [archive].[StructurePlan]
            ([Id], [CleaningId], [Summary], [RulesJson], [RawPlanJson],
             [GeneratedAtUtc], [ArchivedAtUtc])
        SELECT [Id], [CleaningId], [Summary], [RulesJson], [RawPlanJson],
               [GeneratedAtUtc], @stamp
        FROM   [cleaning].[StructurePlan]
        WHERE  [CleaningId] = @Id;
    END;

    IF OBJECT_ID(N'[cleaning].[RedactedFile]', N'U') IS NOT NULL
    BEGIN
        INSERT INTO [archive].[RedactedFile]
            ([Id], [CleaningId], [OriginalFilePath], [OriginalFileName], [Extension],
             [DocumentType], [RedactedContent], [EncryptedPiiJson], [PiiSegmentCount],
             [ContentHash], [DiscoveredAtUtc], [ArchivedAtUtc])
        SELECT [Id], [CleaningId], [OriginalFilePath], [OriginalFileName], [Extension],
               [DocumentType], [RedactedContent], [EncryptedPiiJson], [PiiSegmentCount],
               [ContentHash], [DiscoveredAtUtc], @stamp
        FROM   [cleaning].[RedactedFile]
        WHERE  [CleaningId] = @Id;
    END;

    -- Cowork-parity additions: RedactedFilePiiKind + PromotionRecord
    IF OBJECT_ID(N'[cleaning].[RedactedFilePiiKind]', N'U') IS NOT NULL
    BEGIN
        INSERT INTO [archive].[RedactedFilePiiKind]
            ([Id], [RedactedFileId], [PiiKind], [Count], [CreatedAtUtc], [ArchivedAtUtc])
        SELECT k.[Id], k.[RedactedFileId], k.[PiiKind], k.[Count], k.[CreatedAtUtc], @stamp
        FROM   [cleaning].[RedactedFilePiiKind] k
        JOIN   [cleaning].[RedactedFile]        f ON f.[Id] = k.[RedactedFileId]
        WHERE  f.[CleaningId] = @Id;
    END;

    IF OBJECT_ID(N'[cleaning].[PromotionRecord]', N'U') IS NOT NULL
    BEGIN
        INSERT INTO [archive].[PromotionRecord]
            ([Id], [CleaningId], [FileRelocationId], [OriginalPath], [Status],
             [ErrorMessage], [VerifiedAtUtc], [PromotedAtUtc], [CreatedAtUtc], [ArchivedAtUtc])
        SELECT [Id], [CleaningId], [FileRelocationId], [OriginalPath], [Status],
               [ErrorMessage], [VerifiedAtUtc], [PromotedAtUtc], [CreatedAtUtc], @stamp
        FROM   [cleaning].[PromotionRecord]
        WHERE  [CleaningId] = @Id;
    END;

    -- 3. Delete from working tables in dependency order.
    IF OBJECT_ID(N'[cleaning].[PromotionRecord]', N'U') IS NOT NULL
        DELETE FROM [cleaning].[PromotionRecord] WHERE [CleaningId] = @Id;

    IF OBJECT_ID(N'[cleaning].[FileRelocation]', N'U') IS NOT NULL
        DELETE FROM [cleaning].[FileRelocation] WHERE [CleaningId] = @Id;

    IF OBJECT_ID(N'[cleaning].[StructurePlan]', N'U') IS NOT NULL
        DELETE FROM [cleaning].[StructurePlan] WHERE [CleaningId] = @Id;

    -- RedactedFilePiiKind cascades via FK on RedactedFile delete.
    IF OBJECT_ID(N'[cleaning].[RedactedFile]', N'U') IS NOT NULL
        DELETE FROM [cleaning].[RedactedFile] WHERE [CleaningId] = @Id;

    -- PromptStepCommand cascades via FK on PromptStep delete.
    DELETE FROM [prompts].[PromptStep] WHERE [CleaningId] = @Id;

    DELETE FROM [cleaning].[CleaningFileExtension] WHERE [CleaningId] = @Id;
    DELETE FROM [cleaning].[Cleaning]              WHERE [Id]         = @Id;

    COMMIT TRAN;
END;
GO

-- ─── archive.usp_Cleaning_GetById ────────────────────────────────────────────
CREATE OR ALTER PROCEDURE [archive].[usp_Cleaning_GetById]
    @Id UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [Id], [RootPath], [Status], [CreatedByUserId], [Notes],
           [CreatedAtUtc], [CompletedAtUtc],
           [RestartCount], [LastRestartedAtUtc],
           [ExecutionTarget], [AlternateExecutionPath],
           [BeforeTreeJson], [AfterTreeJson], [ArchivedAtUtc]
    FROM   [archive].[Cleaning]
    WHERE  [Id] = @Id;
END;
GO

-- ─── archive.usp_Cleaning_GetPaged ───────────────────────────────────────────
CREATE OR ALTER PROCEDURE [archive].[usp_Cleaning_GetPaged]
    @Page     INT = 1,
    @PageSize INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [Id], [RootPath], [Status], [CreatedByUserId], [Notes],
           [CreatedAtUtc], [CompletedAtUtc],
           [RestartCount], [LastRestartedAtUtc],
           [ExecutionTarget], [AlternateExecutionPath],
           [BeforeTreeJson], [AfterTreeJson], [ArchivedAtUtc]
    FROM   [archive].[Cleaning]
    ORDER BY [ArchivedAtUtc] DESC
    OFFSET  (@Page - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

PRINT 'archive stored procedures created.';
