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

-- =============================================================================
-- PII pipeline tables (cleaning schema)
-- =============================================================================

-- ─── cleaning.RedactedFile ───────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[cleaning].[RedactedFile]') AND type = 'U')
BEGIN
    CREATE TABLE [cleaning].[RedactedFile]
    (
        [Id]               UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
        [CleaningId]       UNIQUEIDENTIFIER NOT NULL,
        [OriginalFilePath] NVARCHAR(1024)   NOT NULL,
        [OriginalFileName] NVARCHAR(512)    NOT NULL,
        [Extension]        NVARCHAR(32)     NOT NULL,
        [DocumentType]     INT              NOT NULL,
        [RedactedContent]  NVARCHAR(MAX)    NULL,
        [EncryptedPiiJson] NVARCHAR(MAX)    NULL,
        [PiiSegmentCount]  INT              NOT NULL DEFAULT 0,
        [ContentHash]      CHAR(64)         NULL,
        [ImageRedactionRegionsJson] NVARCHAR(MAX) NULL,
        [DiscoveredAtUtc]  DATETIME2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_cleaning_RedactedFile] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data],
        CONSTRAINT [FK_cleaning_RedactedFile_Cleaning]
            FOREIGN KEY ([CleaningId]) REFERENCES [cleaning].[Cleaning]([Id])
    ) ON [FG_Data];
    PRINT 'Table [cleaning].[RedactedFile] created.';
END
ELSE PRINT 'Table [cleaning].[RedactedFile] already exists.';
GO

-- ─── cleaning.StructurePlan ──────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[cleaning].[StructurePlan]') AND type = 'U')
BEGIN
    CREATE TABLE [cleaning].[StructurePlan]
    (
        [Id]             UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
        [CleaningId]     UNIQUEIDENTIFIER NOT NULL,
        [Summary]        NVARCHAR(2000)   NULL,
        [RulesJson]      NVARCHAR(MAX)    NOT NULL,
        [RawPlanJson]    NVARCHAR(MAX)    NULL,
        [GeneratedAtUtc] DATETIME2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_cleaning_StructurePlan] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data],
        CONSTRAINT [FK_cleaning_StructurePlan_Cleaning]
            FOREIGN KEY ([CleaningId]) REFERENCES [cleaning].[Cleaning]([Id])
    ) ON [FG_Data];
    PRINT 'Table [cleaning].[StructurePlan] created.';
END
ELSE PRINT 'Table [cleaning].[StructurePlan] already exists.';
GO

-- ─── cleaning.FileRelocation ─────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[cleaning].[FileRelocation]') AND type = 'U')
BEGIN
    CREATE TABLE [cleaning].[FileRelocation]
    (
        [Id]               UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
        [CleaningId]       UNIQUEIDENTIFIER NOT NULL,
        [RedactedFileId]   UNIQUEIDENTIFIER NULL,
        [OperationType]    INT              NOT NULL,
        [ExecutionTarget]  INT              NOT NULL,
        [BeforePath]       NVARCHAR(1024)   NULL,
        [BeforeName]       NVARCHAR(512)    NULL,
        [AfterPath]        NVARCHAR(1024)   NULL,
        [AfterName]        NVARCHAR(512)    NULL,
        [Status]           INT              NOT NULL DEFAULT 0,
        [ErrorMessage]     NVARCHAR(2000)   NULL,
        [CreatedAtUtc]     DATETIME2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
        [CompletedAtUtc]   DATETIME2(7)     NULL,
        [ContentHashAfter] CHAR(64)         NULL,
        CONSTRAINT [PK_cleaning_FileRelocation] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data],
        CONSTRAINT [FK_cleaning_FileRelocation_Cleaning]
            FOREIGN KEY ([CleaningId]) REFERENCES [cleaning].[Cleaning]([Id]),
        CONSTRAINT [FK_cleaning_FileRelocation_RedactedFile]
            FOREIGN KEY ([RedactedFileId]) REFERENCES [cleaning].[RedactedFile]([Id])
    ) ON [FG_Data];
    PRINT 'Table [cleaning].[FileRelocation] created.';
END
ELSE PRINT 'Table [cleaning].[FileRelocation] already exists.';
GO

-- =============================================================================
-- archive schema — 1:1 mirrors of working tables, plus ArchivedAtUtc.
-- Populated transactionally by cleaning.usp_Cleaning_Archive.
-- =============================================================================

-- ─── archive.Cleaning ────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[archive].[Cleaning]') AND type = 'U')
BEGIN
    CREATE TABLE [archive].[Cleaning]
    (
        [Id]                     UNIQUEIDENTIFIER NOT NULL,
        [RootPath]               NVARCHAR(1024)   NOT NULL,
        [Status]                 TINYINT          NOT NULL,
        [CreatedByUserId]        NVARCHAR(256)    NOT NULL,
        [Notes]                  NVARCHAR(2000)   NULL,
        [CreatedAtUtc]           DATETIME2(7)     NOT NULL,
        [CompletedAtUtc]         DATETIME2(7)     NULL,
        [RestartCount]           INT              NOT NULL DEFAULT 0,
        [LastRestartedAtUtc]     DATETIME2(7)     NULL,
        [ExecutionTarget]        TINYINT          NOT NULL DEFAULT 0,
        [AlternateExecutionPath] NVARCHAR(1024)   NULL,
        [BeforeTreeJson]         NVARCHAR(MAX)    NULL,
        [AfterTreeJson]          NVARCHAR(MAX)    NULL,
        [ArchivedAtUtc]          DATETIME2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_archive_Cleaning] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data]
    ) ON [FG_Data];
    PRINT 'Table [archive].[Cleaning] created.';
END
ELSE PRINT 'Table [archive].[Cleaning] already exists.';
GO

-- ─── archive.CleaningFileExtension ───────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[archive].[CleaningFileExtension]') AND type = 'U')
BEGIN
    CREATE TABLE [archive].[CleaningFileExtension]
    (
        [Id]                    UNIQUEIDENTIFIER NOT NULL,
        [CleaningId]            UNIQUEIDENTIFIER NOT NULL,
        [ExtensionId]           UNIQUEIDENTIFIER NOT NULL,
        [Extension]             NVARCHAR(50)     NOT NULL,
        [FileCount]             INT              NOT NULL,
        [Status]                TINYINT          NOT NULL,
        [SuggestedNuGetPackage] NVARCHAR(512)    NULL,
        [DiscoveredAtUtc]       DATETIME2(7)     NOT NULL,
        [ArchivedAtUtc]         DATETIME2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_archive_CleaningFileExtension] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data]
    ) ON [FG_Data];
    PRINT 'Table [archive].[CleaningFileExtension] created.';
END
ELSE PRINT 'Table [archive].[CleaningFileExtension] already exists.';
GO

-- ─── archive.PromptStep ──────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[archive].[PromptStep]') AND type = 'U')
BEGIN
    CREATE TABLE [archive].[PromptStep]
    (
        [Id]                  UNIQUEIDENTIFIER NOT NULL,
        [CleaningId]          UNIQUEIDENTIFIER NOT NULL,
        [StepOrder]           INT              NOT NULL,
        [StepType]            TINYINT          NOT NULL,
        [PromptText]          NVARCHAR(MAX)    NOT NULL,
        [GeneratedResponse]   NVARCHAR(MAX)    NULL,
        [SourcePath]          NVARCHAR(1024)   NULL,
        [ProposedTargetPath]  NVARCHAR(1024)   NULL,
        [IsApproved]          BIT              NOT NULL,
        [IsExecuted]          BIT              NOT NULL,
        [CreatedAtUtc]        DATETIME2(7)     NOT NULL,
        [ExecutedAtUtc]       DATETIME2(7)     NULL,
        [ExecutionError]      NVARCHAR(2000)   NULL,
        [ArchivedAtUtc]       DATETIME2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_archive_PromptStep] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data]
    ) ON [FG_Data];
    PRINT 'Table [archive].[PromptStep] created.';
END
ELSE PRINT 'Table [archive].[PromptStep] already exists.';
GO

-- ─── archive.PromptStepCommand ───────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[archive].[PromptStepCommand]') AND type = 'U')
BEGIN
    CREATE TABLE [archive].[PromptStepCommand]
    (
        [Id]             UNIQUEIDENTIFIER NOT NULL,
        [PromptStepId]   UNIQUEIDENTIFIER NOT NULL,
        [Language]       TINYINT          NOT NULL,
        [CommandBody]    NVARCHAR(MAX)    NOT NULL,
        [CommandOrder]   INT              NOT NULL,
        [IsExecuted]     BIT              NOT NULL,
        [ExecutedAtUtc]  DATETIME2(7)     NULL,
        [ExecutionError] NVARCHAR(2000)   NULL,
        [CreatedAtUtc]   DATETIME2(7)     NOT NULL,
        [ArchivedAtUtc]  DATETIME2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_archive_PromptStepCommand] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data]
    ) ON [FG_Data];
    PRINT 'Table [archive].[PromptStepCommand] created.';
END
ELSE PRINT 'Table [archive].[PromptStepCommand] already exists.';
GO

-- ─── archive.RedactedFile ────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[archive].[RedactedFile]') AND type = 'U')
BEGIN
    CREATE TABLE [archive].[RedactedFile]
    (
        [Id]               UNIQUEIDENTIFIER NOT NULL,
        [CleaningId]       UNIQUEIDENTIFIER NOT NULL,
        [OriginalFilePath] NVARCHAR(1024)   NOT NULL,
        [OriginalFileName] NVARCHAR(512)    NOT NULL,
        [Extension]        NVARCHAR(32)     NOT NULL,
        [DocumentType]     INT              NOT NULL,
        [RedactedContent]  NVARCHAR(MAX)    NULL,
        [EncryptedPiiJson] NVARCHAR(MAX)    NULL,
        [PiiSegmentCount]  INT              NOT NULL,
        [ContentHash]      CHAR(64)         NULL,
        [ImageRedactionRegionsJson] NVARCHAR(MAX) NULL,
        [DiscoveredAtUtc]  DATETIME2(7)     NOT NULL,
        [ArchivedAtUtc]    DATETIME2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_archive_RedactedFile] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data]
    ) ON [FG_Data];
    PRINT 'Table [archive].[RedactedFile] created.';
END
ELSE PRINT 'Table [archive].[RedactedFile] already exists.';
GO

-- ─── archive.StructurePlan ───────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[archive].[StructurePlan]') AND type = 'U')
BEGIN
    CREATE TABLE [archive].[StructurePlan]
    (
        [Id]             UNIQUEIDENTIFIER NOT NULL,
        [CleaningId]     UNIQUEIDENTIFIER NOT NULL,
        [Summary]        NVARCHAR(2000)   NULL,
        [RulesJson]      NVARCHAR(MAX)    NOT NULL,
        [RawPlanJson]    NVARCHAR(MAX)    NULL,
        [GeneratedAtUtc] DATETIME2(7)     NOT NULL,
        [ArchivedAtUtc]  DATETIME2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_archive_StructurePlan] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data]
    ) ON [FG_Data];
    PRINT 'Table [archive].[StructurePlan] created.';
END
ELSE PRINT 'Table [archive].[StructurePlan] already exists.';
GO

-- ─── archive.FileRelocation ──────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[archive].[FileRelocation]') AND type = 'U')
BEGIN
    CREATE TABLE [archive].[FileRelocation]
    (
        [Id]               UNIQUEIDENTIFIER NOT NULL,
        [CleaningId]       UNIQUEIDENTIFIER NOT NULL,
        [RedactedFileId]   UNIQUEIDENTIFIER NULL,
        [OperationType]    INT              NOT NULL,
        [ExecutionTarget]  INT              NOT NULL,
        [BeforePath]       NVARCHAR(1024)   NULL,
        [BeforeName]       NVARCHAR(512)    NULL,
        [AfterPath]        NVARCHAR(1024)   NULL,
        [AfterName]        NVARCHAR(512)    NULL,
        [Status]           INT              NOT NULL,
        [ErrorMessage]     NVARCHAR(2000)   NULL,
        [CreatedAtUtc]     DATETIME2(7)     NOT NULL,
        [CompletedAtUtc]   DATETIME2(7)     NULL,
        [ContentHashAfter] CHAR(64)         NULL,
        [ArchivedAtUtc]    DATETIME2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_archive_FileRelocation] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data]
    ) ON [FG_Data];
    PRINT 'Table [archive].[FileRelocation] created.';
END
ELSE PRINT 'Table [archive].[FileRelocation] already exists.';
GO

-- ─── cleaning.RedactedFilePiiKind ────────────────────────────────────────────
-- One row per (RedactedFileId, PiiKind) so we can assemble the per-DocumentType
-- slot vocabulary that gets sent to Claude. Count is reserved for future
-- weighting; the slot catalog only consults DISTINCT PiiKind today.
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[cleaning].[RedactedFilePiiKind]') AND type = 'U')
BEGIN
    CREATE TABLE [cleaning].[RedactedFilePiiKind]
    (
        [Id]             UNIQUEIDENTIFIER NOT NULL CONSTRAINT [DF_cleaning_RedactedFilePiiKind_Id] DEFAULT (NEWID()),
        [RedactedFileId] UNIQUEIDENTIFIER NOT NULL,
        [PiiKind]        INT              NOT NULL,
        [Count]          INT              NOT NULL CONSTRAINT [DF_cleaning_RedactedFilePiiKind_Count] DEFAULT (1),
        [CreatedAtUtc]   DATETIME2(7)     NOT NULL CONSTRAINT [DF_cleaning_RedactedFilePiiKind_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_cleaning_RedactedFilePiiKind] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data],
        CONSTRAINT [FK_cleaning_RedactedFilePiiKind_RedactedFile]
            FOREIGN KEY ([RedactedFileId]) REFERENCES [cleaning].[RedactedFile]([Id]) ON DELETE CASCADE
    ) ON [FG_Data];
    PRINT 'Table [cleaning].[RedactedFilePiiKind] created.';
END
ELSE PRINT 'Table [cleaning].[RedactedFilePiiKind] already exists.';
GO

-- ─── cleaning.PromotionRecord ────────────────────────────────────────────────
-- One row per opt-in recycle-bin promotion of a materialized copy.
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[cleaning].[PromotionRecord]') AND type = 'U')
BEGIN
    CREATE TABLE [cleaning].[PromotionRecord]
    (
        [Id]               UNIQUEIDENTIFIER NOT NULL,
        [CleaningId]       UNIQUEIDENTIFIER NOT NULL,
        [FileRelocationId] UNIQUEIDENTIFIER NOT NULL,
        [OriginalPath]     NVARCHAR(1024)   NOT NULL,
        [Status]           INT              NOT NULL,
        [ErrorMessage]     NVARCHAR(2000)   NULL,
        [VerifiedAtUtc]    DATETIME2(7)     NULL,
        [PromotedAtUtc]    DATETIME2(7)     NULL,
        [CreatedAtUtc]     DATETIME2(7)     NOT NULL,
        CONSTRAINT [PK_cleaning_PromotionRecord] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data],
        CONSTRAINT [FK_cleaning_PromotionRecord_Cleaning]
            FOREIGN KEY ([CleaningId]) REFERENCES [cleaning].[Cleaning]([Id]) ON DELETE CASCADE
    ) ON [FG_Data];
    PRINT 'Table [cleaning].[PromotionRecord] created.';
END
ELSE PRINT 'Table [cleaning].[PromotionRecord] already exists.';
GO

-- ─── archive.RedactedFilePiiKind ─────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[archive].[RedactedFilePiiKind]') AND type = 'U')
BEGIN
    CREATE TABLE [archive].[RedactedFilePiiKind]
    (
        [Id]             UNIQUEIDENTIFIER NOT NULL,
        [RedactedFileId] UNIQUEIDENTIFIER NOT NULL,
        [PiiKind]        INT              NOT NULL,
        [Count]          INT              NOT NULL,
        [CreatedAtUtc]   DATETIME2(7)     NOT NULL,
        [ArchivedAtUtc]  DATETIME2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_archive_RedactedFilePiiKind] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data]
    ) ON [FG_Data];
    PRINT 'Table [archive].[RedactedFilePiiKind] created.';
END
ELSE PRINT 'Table [archive].[RedactedFilePiiKind] already exists.';
GO

-- ─── archive.PromotionRecord ─────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[archive].[PromotionRecord]') AND type = 'U')
BEGIN
    CREATE TABLE [archive].[PromotionRecord]
    (
        [Id]               UNIQUEIDENTIFIER NOT NULL,
        [CleaningId]       UNIQUEIDENTIFIER NOT NULL,
        [FileRelocationId] UNIQUEIDENTIFIER NOT NULL,
        [OriginalPath]     NVARCHAR(1024)   NOT NULL,
        [Status]           INT              NOT NULL,
        [ErrorMessage]     NVARCHAR(2000)   NULL,
        [VerifiedAtUtc]    DATETIME2(7)     NULL,
        [PromotedAtUtc]    DATETIME2(7)     NULL,
        [CreatedAtUtc]     DATETIME2(7)     NOT NULL,
        [ArchivedAtUtc]    DATETIME2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [PK_archive_PromotionRecord] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data]
    ) ON [FG_Data];
    PRINT 'Table [archive].[PromotionRecord] created.';
END
ELSE PRINT 'Table [archive].[PromotionRecord] already exists.';
GO

-- ─── cleaning.PathCredential ─────────────────────────────────────────────────
-- Encrypted-at-rest credentials gating remote-share access for a Cleaning.
-- Rows are deleted when the Cleaning is archived; never copied to archive.*.
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
        CONSTRAINT [PK_cleaning_PathCredential] PRIMARY KEY CLUSTERED ([Id]) ON [FG_Data],
        CONSTRAINT [FK_cleaning_PathCredential_Cleaning]
            FOREIGN KEY ([CleaningId]) REFERENCES [cleaning].[Cleaning]([Id]) ON DELETE CASCADE
    ) ON [FG_Data];
    CREATE UNIQUE INDEX [IX_cleaning_PathCredential_Cleaning_RootPath]
        ON [cleaning].[PathCredential] ([CleaningId], [RootPath]);
    PRINT 'Table [cleaning].[PathCredential] created.';
END
ELSE PRINT 'Table [cleaning].[PathCredential] already exists.';
GO

PRINT '03_CreateTables.sql complete.';