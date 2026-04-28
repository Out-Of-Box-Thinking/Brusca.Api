-- =============================================================================
-- 05e_SP_PathCredential.sql
-- Stored procedures for the path-access/credential pipeline (Phase 10).
-- Credentials are written encrypted at rest by the host (IEncryptionService);
-- this file only persists/retrieves the already-encrypted blob.
-- =============================================================================

USE [BruscaDb];
GO

-- ─── cleaning.usp_PathCredential_Save ────────────────────────────────────────
-- Upsert a credential row keyed on (CleaningId, RootPath). Replaces an existing
-- row in place — credentials are not versioned.
CREATE OR ALTER PROCEDURE [cleaning].[usp_PathCredential_Save]
    @Id                UNIQUEIDENTIFIER,
    @CleaningId        UNIQUEIDENTIFIER,
    @RootPath          NVARCHAR(1024),
    @Username          NVARCHAR(256),
    @EncryptedPassword NVARCHAR(MAX),
    @Domain            NVARCHAR(256) = NULL,
    @CreatedAtUtc      DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    MERGE [cleaning].[PathCredential] AS tgt
    USING (SELECT @CleaningId AS CleaningId, @RootPath AS RootPath) AS src
        ON tgt.CleaningId = src.CleaningId AND tgt.RootPath = src.RootPath
    WHEN MATCHED THEN
        UPDATE SET
            [Username]          = @Username,
            [EncryptedPassword] = @EncryptedPassword,
            [Domain]            = @Domain
    WHEN NOT MATCHED THEN
        INSERT ([Id], [CleaningId], [RootPath], [Username],
                [EncryptedPassword], [Domain], [CreatedAtUtc])
        VALUES (@Id, @CleaningId, @RootPath, @Username,
                @EncryptedPassword, @Domain, @CreatedAtUtc);
END;
GO

-- ─── cleaning.usp_PathCredential_Get ─────────────────────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_PathCredential_Get]
    @CleaningId UNIQUEIDENTIFIER,
    @RootPath   NVARCHAR(1024)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [cleaning].[PathCredential]
    SET    [LastUsedAtUtc] = SYSUTCDATETIME()
    WHERE  [CleaningId] = @CleaningId AND [RootPath] = @RootPath;

    SELECT TOP (1)
           [Id], [CleaningId], [RootPath], [Username],
           [EncryptedPassword], [Domain], [CreatedAtUtc], [LastUsedAtUtc]
    FROM   [cleaning].[PathCredential]
    WHERE  [CleaningId] = @CleaningId AND [RootPath] = @RootPath;
END;
GO

-- ─── cleaning.usp_PathCredential_DeleteByCleaningId ──────────────────────────
CREATE OR ALTER PROCEDURE [cleaning].[usp_PathCredential_DeleteByCleaningId]
    @CleaningId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM [cleaning].[PathCredential]
    WHERE  [CleaningId] = @CleaningId;
END;
GO

PRINT '05e_SP_PathCredential.sql complete.';
