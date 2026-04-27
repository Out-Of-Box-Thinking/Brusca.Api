# Brusca Setup Guide

This guide walks a server administrator through every step needed to deploy Brusca on a Windows Server with IIS and SQL Server. All SQL scripts are idempotent — they can be re-run safely without affecting existing data.

---

## Prerequisites checklist

Before starting, confirm every item below is available on the target server.

| Requirement | Minimum version | Notes |
|-------------|----------------|-------|
| Windows Server | 2019 or 2022 | Desktop or Core edition |
| IIS | 10.0 | Enable via Server Manager |
| ASP.NET Core Hosting Bundle | 9.0 | Includes Runtime + IIS module |
| .NET 9 SDK | 9.0 | Development machine only |
| SQL Server | 2019 or 2025 | Express edition works for small deployments |
| SQL Server Management Studio (SSMS) | 20+ | Or Azure Data Studio |
| Node.js | 20 LTS | Development machine only (builds the UI) |
| Anthropic API key | — | https://console.anthropic.com |

---

## Part 1 — Prepare the Windows Server

### 1.1 Install IIS

Open **Server Manager → Add Roles and Features → Server Roles** and enable:

```
Web Server (IIS)
  └── Web Server
        ├── Common HTTP Features
        │     ├── Default Document
        │     ├── Static Content
        │     └── HTTP Errors
        ├── Application Development
        │     ├── ASP.NET 4.8
        │     └── ISAPI Extensions / Filters
        └── Security
              └── Request Filtering
```

Confirm IIS is running by opening `http://localhost` in a browser. You should see the default IIS welcome page.

### 1.2 Install ASP.NET Core Hosting Bundle

1. Download the **ASP.NET Core 9.0 Hosting Bundle** from https://dotnet.microsoft.com/download/dotnet/9.0
2. Run the installer as Administrator.
3. Restart IIS after installation:

```cmd
iisreset /restart
```

4. Verify the ASP.NET Core module is registered:

```cmd
%windir%\System32\inetsrv\appcmd list modules | findstr AspNetCore
```

You should see `AspNetCoreModuleV2`.

### 1.3 Create the application directory

```cmd
mkdir C:\inetpub\Brusca\api
mkdir C:\inetpub\Brusca\ui
mkdir C:\Logs\Brusca\audit
mkdir C:\Logs\Brusca\error
mkdir C:\Logs\Brusca\stdout
```

### 1.4 Create the Application Pool

Open **IIS Manager → Application Pools → Add Application Pool**:

| Setting | Value |
|---------|-------|
| Name | `BruscaAppPool` |
| .NET CLR version | `No Managed Code` |
| Managed pipeline mode | `Integrated` |

After creating the pool, set the identity:

1. Select `BruscaAppPool` → **Advanced Settings**
2. Under **Process Model → Identity**, choose **Custom Account**
3. Enter the service account that has read access to the file shares Brusca will scan

> **Important:** The Application Pool identity must have **read access** to any network shares you intend to scan, and **write access** to `C:\Logs\Brusca`.

### 1.5 Grant log directory permissions

```powershell
# Grant the app pool identity write access to logs
$identity = "IIS AppPool\BruscaAppPool"
$logPath  = "C:\Logs\Brusca"

$acl = Get-Acl $logPath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $identity, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
Set-Acl $logPath $acl
```

---

## Part 2 — SQL Server database setup

All scripts are in the `sql\` directory. They are fully idempotent — run them as many times as needed.

### 2.1 Create data and log directories on the SQL Server

Create these directories on the machine where SQL Server is installed:

```cmd
mkdir C:\SQLData\BruscaDb
mkdir C:\SQLLog\BruscaDb
```

If your SQL Server data files live on a different drive (e.g. `D:\SQLData`), edit **line 18** of `sql\filegroups\01_CreateDatabase.sql` to match your paths before running.

### 2.2 Run the full setup script

From the solution root directory, run all scripts in a single command:

```cmd
sqlcmd -S . -E -i sql\run_all.sql
```

For a named SQL Server instance:

```cmd
sqlcmd -S SERVER_NAME\INSTANCE_NAME -E -i sql\run_all.sql
```

For SQL authentication:

```cmd
sqlcmd -S SERVER_NAME -U sa -P YourPassword -i sql\run_all.sql
```

**Expected output** (abbreviated):

```
BruscaDb created successfully.
Schema [cleaning] created.
...
Table [security].[User] created.
...
Index IX_cleaning_Cleaning_Status created.
...
cleaning.usp_Cleaning_Create created or altered.
...
============================================================
BruscaDb setup complete. All scripts ran successfully.
============================================================
```

If the database already exists, you will see `already exists` messages — this is expected and safe.

### 2.3 Create the application SQL login

Run this in SSMS or `sqlcmd` after the schema is created. Replace the password with a strong value:

```sql
USE [master];
GO

-- Create the login
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'brusca_app')
BEGIN
    CREATE LOGIN [brusca_app] WITH PASSWORD = N'REPLACE_WITH_STRONG_PASSWORD';
    PRINT 'Login brusca_app created.';
END
GO

USE [BruscaDb];
GO

-- Create the database user
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'brusca_app')
BEGIN
    CREATE USER [brusca_app] FOR LOGIN [brusca_app];
    PRINT 'User brusca_app created.';
END
GO

-- Grant EXECUTE-only on all application schemas
GRANT EXECUTE ON SCHEMA::[cleaning]  TO [brusca_app];
GRANT EXECUTE ON SCHEMA::[fileext]   TO [brusca_app];
GRANT EXECUTE ON SCHEMA::[prompts]   TO [brusca_app];
GRANT EXECUTE ON SCHEMA::[security]  TO [brusca_app];
GRANT EXECUTE ON SCHEMA::[audit]     TO [brusca_app];
GRANT EXECUTE ON SCHEMA::[error]     TO [brusca_app];

PRINT 'Permissions granted.';
GO
```

> **Security note:** The application user has EXECUTE-only permission on stored procedures. Direct table reads and writes are denied by default.

### 2.4 Re-running the scripts

All scripts are safe to re-run at any time:

```cmd
sqlcmd -S . -E -i sql\run_all.sql
```

- New tables are created if missing; existing tables are left untouched
- New columns are added if missing (03b script)
- Stored procedures use `CREATE OR ALTER` — always updated to the latest version
- Indexes are created only if they do not already exist

---

## Part 3 — Build the application

Run these commands on your **development machine** (not the server).

### 3.1 Build and publish the API

```powershell
cd Brusca.Api

dotnet publish `
    --configuration Release `
    --runtime win-x64 `
    --self-contained false `
    --output C:\Deploy\BruscaApi
```

This produces a self-contained publish folder at `C:\Deploy\BruscaApi`.

### 3.2 Build the Astro UI

```powershell
cd ..\ui

# Install dependencies
npm install

# Set the API URL for production
$env:PUBLIC_API_URL = "https://brusca.yourdomain.com/api"

# Build
npm run build
# Output is in ui\dist\
```

---

## Part 4 — Deploy to IIS

### 4.1 Copy the API

Copy the contents of `C:\Deploy\BruscaApi` to `C:\inetpub\Brusca\api` on the server:

```powershell
# Run on the server or via file share
robocopy C:\Deploy\BruscaApi \\SERVER\C$\inetpub\Brusca\api /MIR /XF web.config
```

> **Do not overwrite `web.config`** on subsequent deployments if you have made server-specific changes. Use `/XF web.config` with robocopy.

### 4.2 Copy the UI static files

```powershell
robocopy ui\dist \\SERVER\C$\inetpub\Brusca\ui /MIR
```

### 4.3 Create the API website in IIS

Open **IIS Manager → Sites → Add Website**:

| Setting | Value |
|---------|-------|
| Site name | `BruscaApi` |
| Application pool | `BruscaAppPool` |
| Physical path | `C:\inetpub\Brusca\api` |
| Binding type | `https` |
| Host name | `brusca.yourdomain.com` |
| SSL certificate | Select your certificate |

If you do not yet have an SSL certificate, use HTTP for initial testing, then add HTTPS binding and redirect HTTP to HTTPS.

### 4.4 Create the UI website in IIS

Add a second website (or a virtual directory under the same site):

| Setting | Value |
|---------|-------|
| Site name | `BruscaUi` |
| Application pool | `BruscaAppPool` |
| Physical path | `C:\inetpub\Brusca\ui` |
| Binding type | `https` |
| Host name | `brusca-app.yourdomain.com` |

Because the Astro build output is static HTML/JS, no special configuration is needed for the UI beyond serving static files.

---

## Part 5 — Configure secrets and environment variables

Secrets must **never** be stored in `appsettings.json` or `web.config`. Set them as Windows environment variables on the server.

### 5.1 Set environment variables via PowerShell (server)

Run as Administrator on the IIS server:

```powershell
# Database connection string
[System.Environment]::SetEnvironmentVariable(
    "Brusca__DatabaseConnectionString",
    "Server=SQL_SERVER;Database=BruscaDb;User Id=brusca_app;Password=STRONG_PASSWORD;Encrypt=True;TrustServerCertificate=False;",
    "Machine")

# JWT signing key (minimum 32 characters)
[System.Environment]::SetEnvironmentVariable(
    "Brusca__Auth__Jwt__SecretKey",
    "YOUR_MINIMUM_32_CHARACTER_SECRET_KEY_HERE",
    "Machine")

# Anthropic Claude API key
[System.Environment]::SetEnvironmentVariable(
    "Brusca__Claude__ApiKey",
    "sk-ant-YOUR_KEY_HERE",
    "Machine")
```

> ASP.NET Core automatically maps double-underscore `__` in environment variable names to the colon `:` separator in configuration keys. `Brusca__DatabaseConnectionString` maps to `Brusca:DatabaseConnectionString`.

### 5.2 Restart IIS to pick up new environment variables

```cmd
iisreset /restart
```

### 5.3 Verify the API is running

```powershell
Invoke-WebRequest -Uri "https://brusca.yourdomain.com/health" -UseBasicParsing
```

Expected response: `{"status":"Healthy"}` with HTTP 200.

---

## Part 6 — Configure CORS for the UI

Open `C:\inetpub\Brusca\api\appsettings.Production.json` (or set via environment variable) and update `AllowedHosts` and the CORS origin in `Program.cs` to match your UI domain.

In `Program.cs`, the CORS policy `"AstroUi"` allows `http://localhost:4321` and `http://localhost:3000` by default. For production, set the environment variable:

```powershell
[System.Environment]::SetEnvironmentVariable(
    "Brusca__Cors__AllowedOrigins",
    "https://brusca-app.yourdomain.com",
    "Machine")
```

Then update `Program.cs` to read allowed origins from configuration (this is a recommended next step for the developer — see `DeveloperGuide.md`).

---

## Part 7 — Ongoing maintenance

### Re-running SQL scripts after an update

After deploying a new version, always re-run the scripts to pick up schema changes:

```cmd
sqlcmd -S . -E -i sql\run_all.sql
```

The scripts are fully idempotent — existing data is never affected.

### Re-deploying the application

```powershell
# Stop the site to release file locks
Stop-WebSite -Name BruscaApi

# Copy new files
robocopy C:\Deploy\BruscaApi C:\inetpub\Brusca\api /MIR /XF web.config

# Start the site
Start-WebSite -Name BruscaApi
```

### Viewing logs

Error logs (JSON, rolling daily):

```
C:\Logs\Brusca\error\error-YYYYMMDD.json
```

Audit logs (JSON, rolling daily):

```
C:\Logs\Brusca\audit\audit-YYYYMMDD.json
```

IIS stdout log (startup errors, crashes):

```
C:\inetpub\Brusca\api\logs\stdout_*.log
```

Database logs:

```sql
-- Error log
SELECT TOP 100 * FROM [error].[Log] ORDER BY [TimeStamp] DESC;

-- Audit trail
SELECT TOP 100 * FROM [audit].[Log] ORDER BY [CreatedAtUtc] DESC;
```

---

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---------|-------------|------------|
| HTTP 500.30 on startup | Missing .NET 9 hosting bundle | Re-run the Hosting Bundle installer and `iisreset` |
| HTTP 500.31 | ANCM failed to find dotnet | Confirm `dotnet --version` returns 9.x in an admin command prompt |
| `System.InvalidOperationException: Brusca:DatabaseConnectionString is required` | Environment variable not set | Run the PowerShell commands in Part 5.1 and `iisreset` |
| `Cannot open database BruscaDb` | SQL login/permissions | Verify the connection string and that `brusca_app` has EXECUTE permission |
| UI shows CORS error | CORS origin mismatch | Update allowed origins to match the UI domain and restart the API site |
| Logs directory error | Missing directory or permissions | Create `C:\Logs\Brusca\audit` and `C:\Logs\Brusca\error`, grant Modify to the app pool identity |
| `stdout` log file locked | Previous crash left lock | Stop the site, delete old stdout logs, restart |
