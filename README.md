# Brusca.Api

The deployable host for the Brusca AI-powered file organizer. This repo contains the ASP.NET Core 9 REST API, the Astro/React UI, all SQL Server scripts, and end-user/admin documentation.

---

## Repository layout

```
Brusca.Api/              ASP.NET Core 9 web project
  Controllers/           CleaningsController, FileExtensionsController, PromptStepsController
  DTOs/                  Request/response DTO definitions
  Middleware/            Global error handling, request logging
  Properties/            launchSettings.json
  appsettings.json       Base configuration (no secrets)
  appsettings.Production.json
  Program.cs             App bootstrap and DI composition root
  web.config             IIS integration

sql/                     SQL Server setup scripts (fully idempotent)
  run_all.sql            Master runner — execute this to create/update the database
  filegroups/            01_CreateDatabase.sql
  schemas/               02_CreateSchemas.sql
  tables/                03_CreateTables.sql  03b_AlterTables_NewFeatures.sql
  indexes/               04_CreateIndexes.sql
  stored_procedures/     cleaning/ fileext/ prompts/ security/
  security/              06_Security.sql

ui/                      Astro + React Islands front-end
  src/components/        CleaningDashboard, ExtensionsList, TreeComparison, ExecutionTargetModal
  src/pages/             index.astro, extensions.astro
  src/lib/api.ts         Typed API client
  src/stores/            cleaningStore (Nanostores)

docs/                    Project documentation
  SetupGuide.md          IIS / SQL Server deployment for administrators
  UserGuide.md           How to run a Cleaning, review steps, execute changes
  DeveloperGuide.md      Architecture, conventions, adding features, testing
```

---

## Architecture

```
Astro UI  →  Brusca.Api  →  Brusca.Infrastructure (NuGet)  →  Brusca.Core (NuGet)
                                      ↓
                                SQL Server 2025
                                Claude API
                                File System / Network Share
```

**Dependency chain:** `Brusca.Core` ← `Brusca.Infrastructure` ← `Brusca.Api`

---

## Quick start (development)

### Prerequisites
- .NET 9 SDK
- SQL Server (local / Express / Docker)
- Node.js 20 LTS
- Anthropic API key
- `Brusca.Core` and `Brusca.Infrastructure` packed to `../nupkgs` (see below)

### 1. Pack upstream libraries

```powershell
cd ..\Brusca.Core;           .\pack.ps1 -Version 1.0.0
cd ..\Brusca.Infrastructure; .\pack.ps1 -Version 1.0.0
```

### 2. Create the database

```cmd
sqlcmd -S . -E -i sql\run_all.sql
```

All SQL scripts are fully idempotent — safe to re-run at any time.

### 3. Configure secrets

```bash
cd Brusca.Api
dotnet user-secrets set "Brusca:DatabaseConnectionString" "Server=.;Database=BruscaDb;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=True;"
dotnet user-secrets set "Brusca:Auth:Jwt:SecretKey" "dev-secret-minimum-32-characters-here"
dotnet user-secrets set "Brusca:Claude:ApiKey" "sk-ant-..."
```

> All configuration lives under the `Brusca:` key. The **single connection string** at `Brusca:DatabaseConnectionString` is used by every component.

### 4. Run the API

```bash
cd Brusca.Api && dotnet run
# API:     http://localhost:5000
# OpenAPI: http://localhost:5000/scalar
# Health:  http://localhost:5000/health
```

### 5. Run the UI

```bash
cd ui && npm install && npm run dev
# http://localhost:4321
```

---

## Configuration reference

All settings are under the `"Brusca"` key in `appsettings.json`:

| Key | Description | Required |
|-----|-------------|----------|
| `Brusca:DatabaseConnectionString` | SQL Server connection string for everything | **Yes** |
| `Brusca:Auth:Mode` | `Local` or `ActiveDirectory` | No (default: `Local`) |
| `Brusca:Auth:Jwt:SecretKey` | JWT signing key (min 32 chars) | Yes (`Local` mode) |
| `Brusca:Claude:ApiKey` | Anthropic API key | **Yes** |

---

## SQL Server design

### Filegroups
`FG_Data` · `FG_Security` · `FG_Audit` · `FG_Error` · `FG_Index` · `PRIMARY`

### Schemas
`cleaning` · `fileext` · `prompts` · `security` · `audit` · `error`

### Stored procedure convention
```
schema.usp_Entity_Action    e.g.  cleaning.usp_Cleaning_Create
```
All CRUD goes through stored procedures. The application SQL login has EXECUTE-only permission — no direct table access.

---

## Deployment

See [`docs/SetupGuide.md`](docs/SetupGuide.md) for full IIS + SQL Server production deployment instructions.

---

## Target framework

`.NET 9` — `net9.0`  |  Node.js 20 LTS (UI build only)

---

## Related repositories

| Repo | Role |
|------|------|
| [Brusca.Core](../Brusca.Core) | Domain kernel — interfaces and models (NuGet) |
| [Brusca.Infrastructure](../Brusca.Infrastructure) | Infrastructure implementations (NuGet) |
| [Brusca.Tests](../Brusca.Tests) | xUnit integration and unit tests |
