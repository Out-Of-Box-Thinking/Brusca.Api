-- =============================================================================
-- 05c_StoredProcedures_Security.sql
-- =============================================================================

USE [BruscaDb];
GO

-- ─── security.usp_User_Create ────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE [security].[usp_User_Create]
    @Id           UNIQUEIDENTIFIER,
    @Username     NVARCHAR(256),
    @Email        NVARCHAR(512),   -- PII: encrypted at column level in production
    @PasswordHash NVARCHAR(512) = NULL,
    @CreatedAtUtc DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF EXISTS (SELECT 1 FROM [security].[User] WHERE [Username] = @Username)
    BEGIN
        RAISERROR('Username already exists.', 16, 1);
        RETURN;
    END

    INSERT INTO [security].[User]
        ([Id], [Username], [Email], [PasswordHash], [IsActive], [CreatedAtUtc])
    VALUES
        (@Id, @Username, @Email, @PasswordHash, 1, @CreatedAtUtc);

    SELECT [Id], [Username], [IsActive], [CreatedAtUtc]
    FROM   [security].[User]
    WHERE  [Id] = @Id;
END;
GO

-- ─── security.usp_User_GetByUsername ─────────────────────────────────────────
CREATE OR ALTER PROCEDURE [security].[usp_User_GetByUsername]
    @Username NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [Id], [Username], [Email], [PasswordHash],
           [IsActive], [CreatedAtUtc], [LastLoginUtc]
    FROM   [security].[User]
    WHERE  [Username] = @Username AND [IsActive] = 1;
END;
GO

-- ─── security.usp_User_UpdateLastLogin ───────────────────────────────────────
CREATE OR ALTER PROCEDURE [security].[usp_User_UpdateLastLogin]
    @Id           UNIQUEIDENTIFIER,
    @LastLoginUtc DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [security].[User]
    SET    [LastLoginUtc] = @LastLoginUtc
    WHERE  [Id] = @Id;
END;
GO

-- ─── security.usp_RefreshToken_Create ────────────────────────────────────────
CREATE OR ALTER PROCEDURE [security].[usp_RefreshToken_Create]
    @Id           UNIQUEIDENTIFIER,
    @UserId       UNIQUEIDENTIFIER,
    @TokenHash    NVARCHAR(512),
    @ExpiresAtUtc DATETIME2(7),
    @CreatedAtUtc DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Revoke any existing active tokens for this user
    UPDATE [security].[RefreshToken]
    SET    [RevokedAtUtc] = SYSUTCDATETIME()
    WHERE  [UserId] = @UserId AND [RevokedAtUtc] IS NULL;

    INSERT INTO [security].[RefreshToken]
        ([Id], [UserId], [TokenHash], [ExpiresAtUtc], [CreatedAtUtc])
    VALUES
        (@Id, @UserId, @TokenHash, @ExpiresAtUtc, @CreatedAtUtc);
END;
GO

-- ─── security.usp_RefreshToken_Validate ──────────────────────────────────────
CREATE OR ALTER PROCEDURE [security].[usp_RefreshToken_Validate]
    @TokenHash NVARCHAR(512)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT rt.[Id], rt.[UserId], rt.[ExpiresAtUtc], u.[Username], u.[IsActive]
    FROM   [security].[RefreshToken] rt
    JOIN   [security].[User]         u ON u.[Id] = rt.[UserId]
    WHERE  rt.[TokenHash]   = @TokenHash
      AND  rt.[RevokedAtUtc] IS NULL
      AND  rt.[ExpiresAtUtc] > SYSUTCDATETIME()
      AND  u.[IsActive]     = 1;
END;
GO

-- ─── security.usp_RefreshToken_Revoke ────────────────────────────────────────
CREATE OR ALTER PROCEDURE [security].[usp_RefreshToken_Revoke]
    @TokenHash NVARCHAR(512)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [security].[RefreshToken]
    SET    [RevokedAtUtc] = SYSUTCDATETIME()
    WHERE  [TokenHash] = @TokenHash;
END;
GO

PRINT 'security stored procedures created.';
