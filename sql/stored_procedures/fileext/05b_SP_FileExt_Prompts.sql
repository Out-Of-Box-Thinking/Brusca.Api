-- =============================================================================
-- 05b_StoredProcedures_FileExt_Prompts.sql
-- =============================================================================

USE [BruscaDb];
GO

-- ─── fileext.usp_FileExtension_GetAll ────────────────────────────────────────
CREATE OR ALTER PROCEDURE [fileext].[usp_FileExtension_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [Id], [Extension], [Status], [Description],
           [ReaderNuGetPackage], [ReaderImplementationType],
           [TotalTimesEncountered], [FirstSeenUtc], [LastSeenUtc]
    FROM   [fileext].[FileExtension]
    ORDER BY [Extension] ASC;
END;
GO

-- ─── fileext.usp_FileExtension_GetByExtension ────────────────────────────────
CREATE OR ALTER PROCEDURE [fileext].[usp_FileExtension_GetByExtension]
    @Extension NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [Id], [Extension], [Status], [Description],
           [ReaderNuGetPackage], [ReaderImplementationType],
           [TotalTimesEncountered], [FirstSeenUtc], [LastSeenUtc]
    FROM   [fileext].[FileExtension]
    WHERE  [Extension] = LOWER(@Extension);
END;
GO

-- ─── fileext.usp_FileExtension_Upsert ────────────────────────────────────────
CREATE OR ALTER PROCEDURE [fileext].[usp_FileExtension_Upsert]
    @Id                       UNIQUEIDENTIFIER,
    @Extension                NVARCHAR(50),
    @Status                   TINYINT = 0,
    @Description              NVARCHAR(256) = NULL,
    @ReaderNuGetPackage       NVARCHAR(512) = NULL,
    @ReaderImplementationType NVARCHAR(512) = NULL,
    @FirstSeenUtc             DATETIME2(7)  = NULL,
    @LastSeenUtc              DATETIME2(7)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    MERGE [fileext].[FileExtension] AS target
    USING (SELECT LOWER(@Extension) AS Ext) AS src
       ON target.[Extension] = src.Ext
    WHEN MATCHED THEN
        UPDATE SET
            [TotalTimesEncountered] = target.[TotalTimesEncountered] + 1,
            [LastSeenUtc]           = ISNULL(@LastSeenUtc, SYSUTCDATETIME()),
            [Status]                = CASE WHEN @Status > target.[Status] THEN @Status ELSE target.[Status] END,
            [ReaderNuGetPackage]    = ISNULL(@ReaderNuGetPackage, target.[ReaderNuGetPackage]),
            [ReaderImplementationType] = ISNULL(@ReaderImplementationType, target.[ReaderImplementationType])
    WHEN NOT MATCHED THEN
        INSERT ([Id], [Extension], [Status], [Description],
                [ReaderNuGetPackage], [ReaderImplementationType],
                [TotalTimesEncountered], [FirstSeenUtc], [LastSeenUtc])
        VALUES (@Id, LOWER(@Extension), @Status, @Description,
                @ReaderNuGetPackage, @ReaderImplementationType,
                1,
                ISNULL(@FirstSeenUtc, SYSUTCDATETIME()),
                ISNULL(@LastSeenUtc, SYSUTCDATETIME()));
END;
GO

-- ─── fileext.usp_FileExtension_UpdateStatus ──────────────────────────────────
CREATE OR ALTER PROCEDURE [fileext].[usp_FileExtension_UpdateStatus]
    @Extension   NVARCHAR(50),
    @Status      TINYINT,
    @NuGetPackage NVARCHAR(512) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE [fileext].[FileExtension]
    SET    [Status]             = @Status,
           [ReaderNuGetPackage] = ISNULL(@NuGetPackage, [ReaderNuGetPackage])
    WHERE  [Extension] = LOWER(@Extension);
END;
GO

-- ─── prompts.usp_PromptStep_Insert ───────────────────────────────────────────
CREATE OR ALTER PROCEDURE [prompts].[usp_PromptStep_Insert]
    @Id                 UNIQUEIDENTIFIER,
    @CleaningId         UNIQUEIDENTIFIER,
    @StepOrder          INT,
    @StepType           TINYINT,
    @PromptText         NVARCHAR(MAX),
    @SourcePath         NVARCHAR(1024) = NULL,
    @ProposedTargetPath NVARCHAR(1024) = NULL,
    @CreatedAtUtc       DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    INSERT INTO [prompts].[PromptStep]
        ([Id], [CleaningId], [StepOrder], [StepType], [PromptText],
         [SourcePath], [ProposedTargetPath], [CreatedAtUtc])
    VALUES
        (@Id, @CleaningId, @StepOrder, @StepType, @PromptText,
         @SourcePath, @ProposedTargetPath, @CreatedAtUtc);

    SELECT [Id], [CleaningId], [StepOrder], [StepType], [PromptText],
           [GeneratedResponse], [SourcePath], [ProposedTargetPath],
           [IsApproved], [IsExecuted], [CreatedAtUtc], [ExecutedAtUtc], [ExecutionError]
    FROM   [prompts].[PromptStep]
    WHERE  [Id] = @Id;
END;
GO

-- ─── prompts.usp_PromptStep_GetByCleaningId ──────────────────────────────────
CREATE OR ALTER PROCEDURE [prompts].[usp_PromptStep_GetByCleaningId]
    @CleaningId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [Id], [CleaningId], [StepOrder], [StepType], [PromptText],
           [GeneratedResponse], [SourcePath], [ProposedTargetPath],
           [IsApproved], [IsExecuted], [CreatedAtUtc], [ExecutedAtUtc], [ExecutionError]
    FROM   [prompts].[PromptStep]
    WHERE  [CleaningId] = @CleaningId
    ORDER BY [StepOrder] ASC;
END;
GO

-- ─── prompts.usp_PromptStep_UpdateResponse ───────────────────────────────────
CREATE OR ALTER PROCEDURE [prompts].[usp_PromptStep_UpdateResponse]
    @Id                UNIQUEIDENTIFIER,
    @GeneratedResponse NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [prompts].[PromptStep]
    SET    [GeneratedResponse] = @GeneratedResponse
    WHERE  [Id] = @Id;
END;
GO

-- ─── prompts.usp_PromptStep_Approve ──────────────────────────────────────────
CREATE OR ALTER PROCEDURE [prompts].[usp_PromptStep_Approve]
    @Id UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [prompts].[PromptStep]
    SET    [IsApproved] = 1
    WHERE  [Id] = @Id;
END;
GO

-- ─── prompts.usp_PromptStep_MarkExecuted ─────────────────────────────────────
CREATE OR ALTER PROCEDURE [prompts].[usp_PromptStep_MarkExecuted]
    @Id             UNIQUEIDENTIFIER,
    @ExecutedAtUtc  DATETIME2(7),
    @ExecutionError NVARCHAR(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [prompts].[PromptStep]
    SET    [IsExecuted]    = 1,
           [ExecutedAtUtc] = @ExecutedAtUtc,
           [ExecutionError] = @ExecutionError
    WHERE  [Id] = @Id;
END;
GO

PRINT 'fileext and prompts stored procedures created.';
