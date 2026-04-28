# Brusca Developer Guide

This guide covers the project architecture, development environment setup, adding new features, and the conventions that govern every layer of the codebase.

---

## Table of contents

1. [Architecture overview](#architecture-overview)
2. [Development environment setup](#development-environment-setup)
3. [Project structure](#project-structure)
4. [Configuration and connection strings](#configuration-and-connection-strings)
5. [Database conventions](#database-conventions)
6. [Adding a new feature — end-to-end walkthrough](#adding-a-new-feature)
7. [Adding a file reader for an unknown extension](#adding-a-file-reader)
8. [Logging](#logging)
9. [Authentication](#authentication)
10. [Testing](#testing)
11. [Code conventions](#code-conventions)

---

## Architecture overview

```
Astro UI (static, React islands)
    │  HTTP/JSON
    ▼
Brusca.Api  (.NET 9 ASP.NET Core)
    │  IServiceCollection injections
    ▼
Brusca.Infrastructure  (.NET 9 class library)
    │  depends on Core interfaces
    ▼
Brusca.Core  (.NET 9 class library — no concrete deps)
    │  models, interfaces, enums, options
    ├── SQL Server 2025 via Dapper (stored procedures only)
    ├── Anthropic Claude API (Anthropic.SDK)
    ├── File system (local + UNC)
    ├── Serilog → error.Log table / rolling file
    └── Audit.NET → audit.Log table / rolling file
```

### Dependency direction

```
Brusca.Core  ←  Brusca.Infrastructure  ←  Brusca.Api
                                              ↑
                                        Brusca.Tests
```

**Brusca.Core** has zero project references. It defines every interface, model, enum, and option class. Nothing in Core knows about SQL Server, files, or HTTP.

**Brusca.Infrastructure** references Core and implements all its interfaces. All database access goes through Dapper calling stored procedures — no inline SQL anywhere.

**Brusca.Api** references both Core and Infrastructure. It resolves interfaces via DI, exposes REST endpoints, and handles auth middleware.

---

## Development environment setup

### Prerequisites

- .NET 9 SDK: https://dotnet.microsoft.com/download/dotnet/9.0
- SQL Server (local instance, Docker, or Express): https://www.microsoft.com/en-us/sql-server/sql-server-downloads
- Node.js 20 LTS: https://nodejs.org
- Git

### Clone and restore

```bash
git clone <repo-url> Brusca
cd Brusca
dotnet restore
```

### Create the database

```cmd
cd Brusca
sqlcmd -S . -E -i sql\run_all.sql
```

### Configure User Secrets (development)

ASP.NET Core User Secrets keep sensitive values out of source control. Run from the `Brusca.Api` directory:

```bash
cd Brusca.Api

dotnet user-secrets set "Brusca:DatabaseConnectionString" \
    "Server=.;Database=BruscaDb;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=True;"

dotnet user-secrets set "Brusca:Auth:Jwt:SecretKey" \
    "dev-secret-min-32-chars-replace-in-production"

dotnet user-secrets set "Brusca:Claude:ApiKey" "sk-ant-YOUR_KEY"
```

User Secrets are stored in `%APPDATA%\Microsoft\UserSecrets\brusca-api-secrets\secrets.json` and never committed to source control.

### Run the API

```bash
cd Brusca.Api
dotnet run
```

The API starts on `http://localhost:5000`. The Scalar OpenAPI explorer is available at `http://localhost:5000/scalar` in Development mode.

### Run the UI

```bash
cd ui
npm install
npm run dev
```

The UI starts on `http://localhost:4321`. It proxies API calls to `http://localhost:5000` by default (set `PUBLIC_API_URL` to override).

---

## Project structure

```
Brusca/
├── Brusca.Core/
│   ├── Contracts/
│   │   ├── Logging/        IAuditLogger, IErrorLogger
│   │   ├── Repositories/   ICleaningRepository, IPromptStepRepository,
│   │   │                   IPromptStepCommandRepository, IFileExtensionRepository
│   │   └── Services/       ICleaningService, IFileSystemService,
│   │                       IFileExtensionService, ITreeProjectionService
│   ├── Enums/              CleaningStatus, CommandLanguage, ExecutionTarget,
│   │                       FileExtensionStatus, LogSinkTarget, AuthenticationMode
│   └── Models/
│       ├── Cleaning/       Cleaning, CleaningPromptStep, PromptStepCommand,
│       │                   CleaningFileExtension, DirectoryNode, TreeComparisonResult
│       ├── Extensions/     FileExtensionRecord, ExtensionScanResult
│       ├── Logging/        AuditLogEntry, ErrorLogEntry
│       └── Options.cs      BruscaOptions, AuthOptions, LoggingOptions, ClaudeOptions…
│
├── Brusca.Infrastructure/
│   ├── Claude/             ClaudePromptService
│   ├── Configuration/      InfrastructureRegistration (DI extension method)
│   ├── Data/Repositories/  DapperRepositoryBase, CleaningRepository,
│   │                       PromptStepRepository, PromptStepCommandRepository,
│   │                       FileExtensionRepository
│   ├── Logging/            SerilogErrorLogger, AuditNetAuditLogger, LoggingRegistration
│   └── Services/           CleaningService, FileSystemService,
│                           FileExtensionService, TreeProjectionService
│
├── Brusca.Api/
│   ├── Controllers/        CleaningsController, PromptStepsController,
│   │                       FileExtensionsController
│   ├── DTOs/               BruscaDTOs.cs (all request/response records)
│   ├── Middleware/         CorrelationIdMiddleware, GlobalExceptionMiddleware
│   ├── appsettings.json
│   ├── appsettings.Production.json
│   ├── Program.cs
│   └── web.config          IIS hosting configuration
│
├── Brusca.Tests/
│   ├── Core/               CleaningServiceTests
│   ├── Infrastructure/     FileExtensionServiceTests
│   └── Api/                CleaningsControllerTests (integration, opt-in)
│
├── sql/
│   ├── filegroups/         01_CreateDatabase.sql
│   ├── schemas/            02_CreateSchemas.sql
│   ├── tables/             03_CreateTables.sql, 03b_AlterTables_NewFeatures.sql
│   ├── indexes/            04_CreateIndexes.sql
│   ├── stored_procedures/  05a–05d per schema
│   ├── security/           06_Security.sql
│   └── run_all.sql         Master re-runnable script
│
├── docs/
│   ├── SetupGuide.md
│   ├── UserGuide.md
│   └── DeveloperGuide.md  (this file)
│
└── ui/
    └── src/
        ├── components/     CleaningDashboard, TreeComparison, ExecutionTargetModal,
        │                   ExtensionsList
        ├── layouts/        Layout.astro
        ├── lib/            api.ts (typed API client)
        ├── pages/          index.astro, extensions.astro
        └── stores/         cleaningStore.ts (Nanostores)
```

---

## Configuration and connection strings

### Single source of truth: `Brusca:DatabaseConnectionString`

All database connections in the application come from a single key:

```json
{
  "Brusca": {
    "DatabaseConnectionString": "Server=...;Database=BruscaDb;..."
  }
}
```

This key is read by:

- `DapperRepositoryBase` (all repositories)
- `LoggingRegistration` (Serilog MSSqlServer sink + Audit.NET provider)

There is **no separate `ConnectionStrings` section** used by the application code. The `Brusca:DatabaseConnectionString` key is the only place to change the database server.

### Configuration hierarchy

ASP.NET Core merges configuration sources in this order (last wins):

1. `appsettings.json` — defaults, committed to source control (no secrets)
2. `appsettings.{Environment}.json` — environment-specific overrides
3. User Secrets — development-only sensitive values
4. Environment variables — production secrets, IIS deployment

For IIS deployments, set sensitive values as Windows environment variables using double-underscore notation:

```
Brusca__DatabaseConnectionString  →  Brusca:DatabaseConnectionString
Brusca__Auth__Jwt__SecretKey       →  Brusca:Auth:Jwt:SecretKey
Brusca__Claude__ApiKey             →  Brusca:Claude:ApiKey
```

### Adding a new configuration key

1. Add a property to the appropriate options class in `Brusca.Core/Models/Options.cs`
2. Add the key with a development default in `appsettings.json`
3. Add a production placeholder in `appsettings.Production.json`
4. Read it via `IOptions<BruscaOptions>` — never inject `IConfiguration` directly into a repository or service

---

## Database conventions

### Stored procedures only — no inline SQL

Every database operation goes through a named stored procedure. The `DapperRepositoryBase` provides helpers that always set `commandType: CommandType.StoredProcedure`. Inline SQL in a repository will fail code review.

### Naming convention

```
schema.usp_Entity_Action

Examples:
  cleaning.usp_Cleaning_Create
  cleaning.usp_Cleaning_UpdateStatus
  prompts.usp_PromptStepCommand_GetByStepId
  security.usp_User_GetByUsername
```

### Adding a new stored procedure

1. Write the T-SQL in the appropriate `sql/stored_procedures/<schema>/` file
2. Use `CREATE OR ALTER PROCEDURE` — this makes every SP idempotent
3. Add the corresponding C# method to the repository interface in `Brusca.Core/Contracts/Repositories/IRepositories.cs`
4. Implement the method in the repository in `Brusca.Infrastructure/Data/Repositories/`
5. Run `sqlcmd -S . -E -i sql\run_all.sql` to deploy the new SP

### Schema placement

| Schema | Purpose | Filegroup |
|--------|---------|-----------|
| `cleaning` | Cleaning runs, file extensions per run | `FG_Data` |
| `fileext` | Master extension list | `FG_Data` |
| `prompts` | PromptStep, PromptStepCommand | `FG_Data` |
| `security` | Users, roles, tokens | `FG_Security` |
| `audit` | Audit log (Audit.NET) | `FG_Audit` |
| `error` | Error log (Serilog) | `FG_Error` |

All non-clustered indexes go on `FG_Index`. Always specify `ON [FG_Index]` in index DDL.

### Re-runnable scripts

All SQL scripts use idempotency guards:

```sql
-- Tables
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[schema].[Table]') AND type = 'U')
BEGIN
    CREATE TABLE ...
END

-- Schemas
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'schema_name')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA [schema_name]';
END

-- Stored procedures — always re-deployable
CREATE OR ALTER PROCEDURE [schema].[usp_Entity_Action] ...

-- Indexes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_...' AND object_id = OBJECT_ID(N'[schema].[Table]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_...] ...
END
```

Never use `DROP + CREATE` for tables in scripts that will run against production databases.

---

## Adding a new feature

The pattern below applies to any new domain entity or operation.

### 1. Define the model in Core

Add a new class to the appropriate folder under `Brusca.Core/Models/`. Use `sealed` classes with `init`-only setters for immutable fields.

### 2. Add the repository interface in Core

Open `Brusca.Core/Contracts/Repositories/IRepositories.cs` and add a new `public interface IYourEntityRepository` following the existing patterns. Use `Task<Result<T>>` return types from the `FluentResults` package.

### 3. Add the service interface in Core

Open `Brusca.Core/Contracts/Services/IServices.cs` and add any service contract methods needed.

### 4. Write the SQL stored procedure

Create a file `sql/stored_procedures/<schema>/XX_SP_YourEntity.sql` with `CREATE OR ALTER PROCEDURE` statements. Add entries to `sql/run_all.sql`.

### 5. Add table/columns if needed

If new columns or tables are needed, add them to `sql/tables/03_CreateTables.sql` using `IF NOT EXISTS` guards. For existing databases, also add an ALTER TABLE migration to `sql/tables/03b_AlterTables_NewFeatures.sql` guarded the same way.

### 6. Implement the repository in Infrastructure

Create `Brusca.Infrastructure/Data/Repositories/YourEntityRepository.cs` extending `DapperRepositoryBase`. Register it in `InfrastructureRegistration.cs`.

### 7. Implement the service in Infrastructure

Create `Brusca.Infrastructure/Services/YourEntityService.cs`. Register it in `InfrastructureRegistration.cs`.

### 8. Add DTOs in the API

Add request and response records to `Brusca.Api/DTOs/BruscaDTOs.cs`.

### 9. Add a controller

Create `Brusca.Api/Controllers/YourEntityController.cs`. Apply `[Authorize]` and return `ApiResult<T>` wrappers.

### 10. Add UI components and API client methods

Add typed methods to `ui/src/lib/api.ts`. Create React components in `ui/src/components/`. Wire them into a page.

---

## Adding a file reader

When a user encounters an unknown file extension, the application blocks until a reader is registered and deployed.

### Step 1 — Register the extension in the UI

The user enters the NuGet package name in the blocking modal. This writes to `fileext.FileExtension.ReaderNuGetPackage`.

### Step 2 — Add the NuGet package

```bash
cd Brusca.Infrastructure
dotnet add package YourPackageName
```

### Step 3 — Implement IFileReaderService

Create a new file `Brusca.Infrastructure/Services/Readers/YourExtensionReader.cs`:

```csharp
using Brusca.Core.Contracts.Services;
using FluentResults;

namespace Brusca.Infrastructure.Services.Readers;

public sealed class ExcelFileReader : IFileReaderService
{
    public IReadOnlyList<string> SupportedExtensions => [".xls", ".xlsx"];

    public bool CanRead(string extension) =>
        SupportedExtensions.Contains(extension, StringComparer.OrdinalIgnoreCase);

    public async Task<Result<string>> ReadAsync(string filePath, CancellationToken ct = default)
    {
        try
        {
            // Use your NuGet package here to extract text content
            using var stream = File.OpenRead(filePath);
            // ... extract text ...
            return Result.Ok("extracted text content");
        }
        catch (Exception ex)
        {
            return Result.Fail(new ExceptionalError(ex));
        }
    }
}
```

### Step 4 — Register the reader

In `InfrastructureRegistration.cs`:

```csharp
// Register as a named implementation — the factory picks the right reader per extension
services.AddScoped<IFileReaderService, ExcelFileReader>();
services.AddScoped<IFileReaderService, PdfFileReader>();
// etc.
```

Consider implementing a `FileReaderFactory` that picks the correct `IFileReaderService` based on file extension.

### Step 5 — Update the extension status

After deployment, re-run `sqlcmd -S . -E -i sql\run_all.sql`. The user then restarts the Cleaning from the UI and scans again.

---

## Logging

### Error logging — Serilog

Use `IErrorLogger` (injected from DI) throughout the application:

```csharp
await _log.LogErrorAsync("Descriptive message", ex, correlationId, cleaningId);
await _log.LogWarningAsync("Something unexpected happened", correlationId);
await _log.LogInformationAsync("Step completed", correlationId);
```

Do **not** use `ILogger<T>` from Microsoft.Extensions.Logging directly — always use `IErrorLogger` so logs route through the configured sinks.

### Audit logging — Audit.NET

Use `IAuditLogger` for all business-significant events:

```csharp
await _audit.LogAsync(
    eventType: "CleaningStarted",
    entityType: "Cleaning",
    entityId: cleaning.Id.ToString(),
    userId: userId,
    action: "Create",
    oldValues: null,
    newValues: cleaning);
```

Audit entries are written to `audit.Log` and/or a rolling JSON file, depending on `Brusca:Logging:Audit:Sink`.

### Sink configuration

Both loggers read from `Brusca:Logging:Audit` and `Brusca:Logging:Error` in `appsettings.json`:

| `Sink` value | Destination |
|-------------|------------|
| `Database` | SQL Server table only |
| `File` | Rolling JSON file only |
| `Both` | SQL Server table + rolling JSON file |
| `Elasticsearch` | Elasticsearch index |

Changing the sink requires restarting the application — it is read at startup.

---

## Authentication

Authentication mode is controlled by `Brusca:Auth:Mode` in `appsettings.json`.

### Local JWT (default)

Users are stored in `security.User`. Passwords are hashed. JWT tokens are issued by your auth controller (not included in this scaffold — implement `POST /api/auth/login` that calls `security.usp_User_GetByUsername`, verifies the hash, and returns a signed JWT).

The signing key comes from `Brusca:Auth:Jwt:SecretKey`. Set this via User Secrets in development and environment variables in production.

### Azure Active Directory

Set `"Mode": "ActiveDirectory"` in `appsettings.json` and populate:

```json
"AzureAd": {
    "TenantId": "your-tenant-id",
    "ClientId": "your-client-id"
}
```

The `Microsoft.Identity.Web` package (already referenced in `Brusca.Api.csproj`) handles token validation. No code changes required — the `Program.cs` switch selects the correct authentication pipeline at startup.

To toggle between modes without redeploying, set the environment variable:

```powershell
[System.Environment]::SetEnvironmentVariable("Brusca__Auth__Mode", "ActiveDirectory", "Machine")
iisreset /restart
```

---

## Testing

### Unit tests

```bash
dotnet test Brusca.Tests
```

All unit tests use `Moq` for interface mocking and `FluentAssertions` for readable assertions. Tests are in:

- `Brusca.Tests/Core/` — service logic tests
- `Brusca.Tests/Infrastructure/` — repository and service tests (mocked dependencies)

### Integration tests

Integration tests require a running SQL Server. They are gated by an environment variable:

```bash
# Enable integration tests
$env:BRUSCA_INTEGRATION_TESTS = "true"
dotnet test Brusca.Tests --filter "Category=Integration"
```

### Adding a new test

Follow the AAA (Arrange / Act / Assert) pattern:

```csharp
[Fact]
public async Task MethodName_Scenario_ExpectedResult()
{
    // Arrange
    var mockRepo = new Mock<ICleaningRepository>();
    mockRepo.Setup(r => r.GetByIdAsync(It.IsAny<Guid>(), default))
            .ReturnsAsync(Result.Ok(new Cleaning { ... }));
    var sut = new CleaningService(mockRepo.Object, ...);

    // Act
    var result = await sut.GetCleaningAsync(Guid.NewGuid());

    // Assert
    result.IsSuccess.Should().BeTrue();
    result.Value.Status.Should().Be(CleaningStatus.Pending);
}
```

---

## Code conventions

### C#

- All C# targets **net9.0** with `Nullable enable` and `ImplicitUsings enable`
- Use `sealed` on all non-abstract classes
- Use `record` for DTOs and value objects; `class` for domain entities
- Return `Result<T>` from all repository and service methods — never throw from infrastructure
- Use `CancellationToken ct = default` on every async public method
- No inline SQL — every database call goes through a stored procedure

### Naming

| Element | Convention | Example |
|---------|------------|---------|
| Interfaces | `I` prefix | `ICleaningRepository` |
| Implementations | No prefix | `CleaningRepository` |
| Options classes | `Options` suffix | `BruscaOptions`, `AuthOptions` |
| Stored procedures | `schema.usp_Entity_Action` | `cleaning.usp_Cleaning_Create` |
| SQL indexes | `IX_schema_table_columns` | `IX_cleaning_Cleaning_Status` |
| TypeScript types | PascalCase | `CleaningResponse` |
| TypeScript stores | camelCase atom names | `activeCleaning`, `scanResult` |

### Pull request checklist

Before submitting a PR, confirm:

- [ ] New SQL objects use `IF NOT EXISTS` or `CREATE OR ALTER` guards
- [ ] `run_all.sql` includes any new scripts
- [ ] All database access goes through stored procedures
- [ ] Connection string reads from `Brusca:DatabaseConnectionString`
- [ ] New service methods log via `IErrorLogger` or `IAuditLogger`
- [ ] New public API methods have `[Authorize]` and return `ApiResult<T>`
- [ ] Unit tests cover the happy path and at least one failure path
- [ ] No secrets committed to source control

---

## Frequently asked questions

**Why Dapper instead of Entity Framework?**
All business logic is in stored procedures, so an ORM's change-tracking and migration system would add complexity without value. Dapper is a thin wrapper around ADO.NET that maps stored procedure results to C# objects with minimal overhead.

**Why FluentResults instead of throwing exceptions?**
Exceptions are for truly unexpected failures. Business outcomes like "cleaning not found" or "extension unknown" are expected and should be communicated as typed results, not stack traces. FluentResults keeps error handling at the call site and makes it easy to compose results without try-catch towers.

**Why is the connection string in `Brusca:DatabaseConnectionString` rather than `ConnectionStrings:BruscaDb`?**
The entire application configuration is unified under the `Brusca` key so it can be managed as a single configuration object. Having the connection string inside `Brusca:` means all configuration that controls Brusca's behavior is in one place, with one `BruscaOptions` class binding it all.

**How do I add a second database (e.g. for read replicas)?**
Add `ReadOnlyDatabaseConnectionString` to `BruscaOptions`, read it in `DapperRepositoryBase` for read-only query methods, and add it to `appsettings.json`.


---

## PII pipeline integration (NEW)

The PII redaction + structure-planning pipeline lives across two services and three repositories:

| Layer | Type | Role |
|-------|------|------|
| `IPiiRedactionService`     | service    | strip PII -> token + segments |
| `IDocumentTypeClassifier`  | service    | redacted text + extension -> `DocumentType` |
| `IEncryptionService`       | service    | seal PII JSON column |
| `IClaudeStructureService`  | service    | anonymized Claude call |
| `IStructureExecutionService` | service  | apply plan + record before/after |
| `IRedactedFileRepository`  | repository | per-file descriptor + encrypted PII |
| `IStructurePlanRepository` | repository | persisted plans |
| `IFileRelocationRepository`| repository | before/after operation log |

All five services and three repositories are registered by `AddBruscaInfrastructure(configuration)`. To replace one, register your replacement AFTER that call:

`csharp
builder.Services.AddBruscaInfrastructure(builder.Configuration);
builder.Services.Replace(ServiceDescriptor.Scoped<IPiiRedactionService, MyMlPiiRedactionService>());
`

### Endpoint -> service mapping

| Endpoint | Service method |
|----------|----------------|
| `POST /redact`             | `ICleaningService.RedactAndClassifyAsync` |
| `POST /generate-structure` | `ICleaningService.GenerateStructurePlanAsync` |
| `GET  /structure-plan`     | `ICleaningService.GetStructurePlanAsync` |
| `POST /execute-structure`  | `ICleaningService.ExecuteStructurePlanAsync` |
| `GET  /relocations`        | `ICleaningService.GetRelocationsAsync` |

### Privacy invariants \u2014 DO NOT BREAK

1. Don't send raw file content to Claude. Only `DocumentTypeBucketResponse` aggregates are permitted.
2. Don't log PII. The `IErrorLogger`/`IAuditLogger` calls in this repo intentionally never include `PiiSegment.Value`.
3. Don't persist PII in cleartext. The only acceptable column is `cleaning.RedactedFile.EncryptedPiiJson`.
4. Don't return PII in API responses. `RedactedFileResponse` never includes the encrypted blob.
5. Don't decrypt PII anywhere except inside `StructureExecutionService.BuildTokenMap` for the duration of one file operation.
