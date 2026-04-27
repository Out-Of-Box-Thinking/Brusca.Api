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
