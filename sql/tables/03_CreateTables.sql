-- =============================================================================
-- 03_CreateTables.sql  (RE-RUNNABLE / IDEMPOTENT)
-- Creates all tables using IF NOT EXISTS guards.
-- Safe to re-run: existing tables and their data are never dropped.
--
-- PII columns (Email, IpAddress) are marked for Always Encrypted in production.
-- In dev/test they remain plain NVARCHAR. See 06_Security.sql for AE setup.
-- =============================================================================

USE [BruscaDb];
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- security.User
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[security].[User]') AND type = 'U')
BEGIN
    CREATE TABLE [security].[User]
    (
        [Id]           UNIQUEIDENTIFIER  NOT NULL  DEFAULT NEWSEQUENTIALID(),
        [Username]     NVARCHAR(256)     NOT NULL,
        [Email]        NVARCHAR(512)     NOT NULL,  -- PII: Always Encrypted in production
        [PasswordHash] NVARCHAR(512)     NULL,
        [IsActive]     BIT               NOT NULL  DEFAULT 1,
        [CreatedAtUtc] DATETIME2(7)      NOT NULL  DEFAULT SYSUTCDATETIME(),
        [LastLoginUtc] DATETIME2(7)      NULL,
        CONSTRAINT [PK_security_User] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Security]
    ) ON [FG_Security];
    PRINT 'Table [security].[User] created.';
END
ELSE PRINT 'Table [security].[User] already exists.';
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[security].[Role]') AND type = 'U')
BEGIN
    CREATE TABLE [security].[Role]
    (
        [Id]          UNIQUEIDENTIFIER  NOT NULL  DEFAULT NEWSEQUENTIALID(),
        [Name]        NVARCHAR(128)     NOT NULL,
        [Description] NVARCHAR(512)     NULL,
        CONSTRAINT [PK_security_Role] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Security]
    ) ON [FG_Security];
    PRINT 'Table [security].[Role] created.';
END
ELSE PRINT 'Table [security].[Role] already exists.';
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[security].[UserRole]') AND type = 'U')
BEGIN
    CREATE TABLE [security].[UserRole]
    (
        [UserId] UNIQUEIDENTIFIER NOT NULL,
        [RoleId] UNIQUEIDENTIFIER NOT NULL,
        CONSTRAINT [PK_security_UserRole] PRIMARY KEY CLUSTERED ([UserId], [RoleId]) ON [FG_Security],
        CONSTRAINT [FK_security_UserRole_User] FOREIGN KEY ([UserId]) REFERENCES [security].[User]([Id]),
        CONSTRAINT [FK_security_UserRole_Role] FOREIGN KEY ([RoleId]) REFERENCES [security].[Role]([Id])
    ) ON [FG_Security];
    PRINT 'Table [security].[UserRole] created.';
END
ELSE PRINT 'Table [security].[UserRole] already exists.';
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[security].[RefreshToken]') AND type = 'U')
BEGIN
    CREATE TABLE [security].[RefreshToken]
    (
        [Id]           UNIQUEIDENTIFIER  NOT NULL  DEFAULT NEWSEQUENTIALID(),
        [UserId]       UNIQUEIDENTIFIER  NOT NULL,
        [TokenHash]    NVARCHAR(512)     NOT NULL,
        [ExpiresAtUtc] DATETIME2(7)      NOT NULL,
        [CreatedAtUtc] DATETIME2(7)      NOT NULL  DEFAULT SYSUTCDATETIME(),
        [RevokedAtUtc] DATETIME2(7)      NULL,
        CONSTRAINT [PK_security_RefreshToken] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Security],
        CONSTRAINT [FK_security_RefreshToken_User] FOREIGN KEY ([UserId]) REFERENCES [security].[User]([Id])
    ) ON [FG_Security];
    PRINT 'Table [security].[RefreshToken] created.';
END
ELSE PRINT 'Table [security].[RefreshToken] already exists.';
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- fileext.FileExtension  (master list)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[fileext].[FileExtension]') AND type = 'U')
BEGIN
    CREATE TABLE [fileext].[FileExtension]
    (
        [Id]                        UNIQUEIDENTIFIER  NOT NULL  DEFAULT NEWSEQUENTIALID(),
        [Extension]                 NVARCHAR(50)      NOT NULL,
        [Status]                    TINYINT           NOT NULL  DEFAULT 0,
        [Description]               NVARCHAR(256)     NULL,
        [ReaderNuGetPackage]        NVARCHAR(512)     NULL,
        [ReaderImplementationType]  NVARCHAR(512)     NULL,
        [TotalTimesEncountered]     INT               NOT NULL  DEFAULT 0,
        [FirstSeenUtc]              DATETIME2(7)      NOT NULL  DEFAULT SYSUTCDATETIME(),
        [LastSeenUtc]               DATETIME2(7)      NOT NULL  DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_fileext_FileExtension] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data],
        CONSTRAINT [UQ_fileext_FileExtension_Extension] UNIQUE ([Extension]) ON [FG_Data]
    ) ON [FG_Data];
    PRINT 'Table [fileext].[FileExtension] created.';
END
ELSE PRINT 'Table [fileext].[FileExtension] already exists.';
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- cleaning.Cleaning
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[cleaning].[Cleaning]') AND type = 'U')
BEGIN
    CREATE TABLE [cleaning].[Cleaning]
    (
        [Id]                     UNIQUEIDENTIFIER  NOT NULL  DEFAULT NEWSEQUENTIALID(),
        [RootPath]               NVARCHAR(1024)    NOT NULL,
        [Status]                 TINYINT           NOT NULL  DEFAULT 0,
        [CreatedByUserId]        NVARCHAR(256)     NOT NULL,
        [Notes]                  NVARCHAR(2000)    NULL,
        [CreatedAtUtc]           DATETIME2(7)      NOT NULL  DEFAULT SYSUTCDATETIME(),
        [CompletedAtUtc]         DATETIME2(7)      NULL,
        -- Restart support
        [RestartCount]           INT               NOT NULL  DEFAULT 0,
        [LastRestartedAtUtc]     DATETIME2(7)      NULL,
        -- Execution target
        [ExecutionTarget]        TINYINT           NOT NULL  DEFAULT 0,
        [AlternateExecutionPath] NVARCHAR(1024)    NULL,
        -- Tree snapshots
        [BeforeTreeJson]         NVARCHAR(MAX)     NULL,
        [AfterTreeJson]          NVARCHAR(MAX)     NULL,
        CONSTRAINT [PK_cleaning_Cleaning] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data]
    ) ON [FG_Data];
    PRINT 'Table [cleaning].[Cleaning] created.';
END
ELSE PRINT 'Table [cleaning].[Cleaning] already exists.';
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- cleaning.CleaningFileExtension
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[cleaning].[CleaningFileExtension]') AND type = 'U')
BEGIN
    CREATE TABLE [cleaning].[CleaningFileExtension]
    (
        [Id]                    UNIQUEIDENTIFIER  NOT NULL  DEFAULT NEWSEQUENTIALID(),
        [CleaningId]            UNIQUEIDENTIFIER  NOT NULL,
        [ExtensionId]           UNIQUEIDENTIFIER  NOT NULL,
        [Extension]             NVARCHAR(50)      NOT NULL,
        [FileCount]             INT               NOT NULL  DEFAULT 0,
        [Status]                TINYINT           NOT NULL  DEFAULT 0,
        [SuggestedNuGetPackage] NVARCHAR(512)     NULL,
        [DiscoveredAtUtc]       DATETIME2(7)      NOT NULL  DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_cleaning_CleaningFileExtension] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data],
        CONSTRAINT [FK_cleaning_CleaningFileExtension_Cleaning]
            FOREIGN KEY ([CleaningId]) REFERENCES [cleaning].[Cleaning]([Id]),
        CONSTRAINT [FK_cleaning_CleaningFileExtension_FileExtension]
            FOREIGN KEY ([ExtensionId]) REFERENCES [fileext].[FileExtension]([Id])
    ) ON [FG_Data];
    PRINT 'Table [cleaning].[CleaningFileExtension] created.';
END
ELSE PRINT 'Table [cleaning].[CleaningFileExtension] already exists.';
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- prompts.PromptStep
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[prompts].[PromptStep]') AND type = 'U')
BEGIN
    CREATE TABLE [prompts].[PromptStep]
    (
        [Id]                  UNIQUEIDENTIFIER  NOT NULL  DEFAULT NEWSEQUENTIALID(),
        [CleaningId]          UNIQUEIDENTIFIER  NOT NULL,
        [StepOrder]           INT               NOT NULL,
        [StepType]            TINYINT           NOT NULL  DEFAULT 0,
        [PromptText]          NVARCHAR(MAX)     NOT NULL,
        [GeneratedResponse]   NVARCHAR(MAX)     NULL,
        [SourcePath]          NVARCHAR(1024)    NULL,
        [ProposedTargetPath]  NVARCHAR(1024)    NULL,
        [IsApproved]          BIT               NOT NULL  DEFAULT 0,
        [IsExecuted]          BIT               NOT NULL  DEFAULT 0,
        [CreatedAtUtc]        DATETIME2(7)      NOT NULL  DEFAULT SYSUTCDATETIME(),
        [ExecutedAtUtc]       DATETIME2(7)      NULL,
        [ExecutionError]      NVARCHAR(2000)    NULL,
        CONSTRAINT [PK_prompts_PromptStep] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data],
        CONSTRAINT [FK_prompts_PromptStep_Cleaning]
            FOREIGN KEY ([CleaningId]) REFERENCES [cleaning].[Cleaning]([Id]),
        CONSTRAINT [UQ_prompts_PromptStep_CleaningOrder] UNIQUE ([CleaningId], [StepOrder]) ON [FG_Data]
    ) ON [FG_Data];
    PRINT 'Table [prompts].[PromptStep] created.';
END
ELSE PRINT 'Table [prompts].[PromptStep] already exists.';
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- prompts.PromptStepCommand
-- Each PromptStep has 1-N commands — one per language (C#, CMD, PowerShell).
-- FK uses ON DELETE CASCADE so deleting a step removes its commands.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[prompts].[PromptStepCommand]') AND type = 'U')
BEGIN
    CREATE TABLE [prompts].[PromptStepCommand]
    (
        [Id]             UNIQUEIDENTIFIER  NOT NULL  DEFAULT NEWSEQUENTIALID(),
        [PromptStepId]   UNIQUEIDENTIFIER  NOT NULL,
        [Language]       TINYINT           NOT NULL  DEFAULT 2,  -- 0=CSharp, 1=Cmd, 2=PowerShell
        [CommandBody]    NVARCHAR(MAX)     NOT NULL,
        [CommandOrder]   INT               NOT NULL  DEFAULT 1,
        [IsExecuted]     BIT               NOT NULL  DEFAULT 0,
        [ExecutedAtUtc]  DATETIME2(7)      NULL,
        [ExecutionError] NVARCHAR(2000)    NULL,
        [CreatedAtUtc]   DATETIME2(7)      NOT NULL  DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_prompts_PromptStepCommand] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data],
        CONSTRAINT [FK_prompts_PromptStepCommand_Step]
            FOREIGN KEY ([PromptStepId]) REFERENCES [prompts].[PromptStep]([Id]) ON DELETE CASCADE
    ) ON [FG_Data];
    PRINT 'Table [prompts].[PromptStepCommand] created.';
END
ELSE PRINT 'Table [prompts].[PromptStepCommand] already exists.';
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- audit.Log  (Audit.NET target)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[audit].[Log]') AND type = 'U')
BEGIN
    CREATE TABLE [audit].[Log]
    (
        [Id]           BIGINT         IDENTITY(1,1) NOT NULL,
        [EventType]    NVARCHAR(256)  NOT NULL,
        [EntityType]   NVARCHAR(256)  NULL,
        [EntityId]     NVARCHAR(256)  NULL,
        [UserId]       NVARCHAR(256)  NULL,
        [IpAddress]    NVARCHAR(64)   NULL,  -- PII: Always Encrypted in production
        [Data]         NVARCHAR(MAX)  NULL,
        [CreatedAtUtc] DATETIME2(7)   NOT NULL  DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_audit_Log] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Audit]
    ) ON [FG_Audit];
    PRINT 'Table [audit].[Log] created.';
END
ELSE PRINT 'Table [audit].[Log] already exists.';
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- error.Log  (Serilog MSSqlServer sink target)
-- Column names match Serilog.Sinks.MSSqlServer defaults exactly.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[error].[Log]') AND type = 'U')
BEGIN
    CREATE TABLE [error].[Log]
    (
        [Id]              BIGINT          IDENTITY(1,1) NOT NULL,
        [Message]         NVARCHAR(MAX)   NULL,
        [MessageTemplate] NVARCHAR(MAX)   NULL,
        [Level]           NVARCHAR(128)   NULL,
        [TimeStamp]       DATETIMEOFFSET  NOT NULL  DEFAULT SYSDATETIMEOFFSET(),
        [Exception]       NVARCHAR(MAX)   NULL,
        [Properties]      NVARCHAR(MAX)   NULL,
        [CorrelationId]   NVARCHAR(128)   NULL,
        [CleaningId]      UNIQUEIDENTIFIER NULL,
        [UserId]          NVARCHAR(256)   NULL,
        CONSTRAINT [PK_error_Log] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Error]
    ) ON [FG_Error];
    PRINT 'Table [error].[Log] created.';
END
ELSE PRINT 'Table [error].[Log] already exists.';
GO

PRINT '03_CreateTables.sql complete.';
