# Install Guide — Brusca.Api

`Brusca.Api` is the ASP.NET Core 9 REST surface that fronts the cleaning + PII-redaction + structure-planning pipelines.

---

## 1. Prerequisites

| Tool | Version |
|------|---------|
| .NET SDK | 9.0+ |
| SQL Server | 2022+ |
| Anthropic API key | for Claude |
| (optional) Visual Studio | 2026 |

The Brusca.Core and Brusca.Infrastructure NuGet packages must already be present in the shared `..\nupkgs` feed (see those repos' `InstallGuide.md`).

---

## 2. Step-by-step install

```powershell
# 1) Make sure the shared feed exists and has both Brusca.Core and Brusca.Infrastructure packed.
ls \\OOBT-NAS\Workstation\Repo\nupkgs\Brusca.*.nupkg

# 2) Clone (or pull) Brusca.Api alongside the other repos.
cd \\OOBT-NAS\Workstation\Repo
git clone https://github.com/Out-Of-Box-Thinking/Brusca.Api.git

# 3) Restore + build.
cd Brusca.Api
dotnet restore Brusca.Api/Brusca.Api.csproj --force
dotnet build   Brusca.Api/Brusca.Api.csproj -c Debug
```

If `dotnet restore` reports the local feed missing, create it once with `New-Item -ItemType Directory -Path \\OOBT-NAS\Workstation\Repo\nupkgs -Force`.

---

## 3. Configure secrets

The API needs three secrets — never commit them.

### 3.1 Database connection string

Set the single authoritative connection string at `Brusca:DatabaseConnectionString`. Used by Dapper, Serilog's MSSqlServer sink, the Audit.NET SQL provider, and the SQL Server health check.

```powershell
cd Brusca.Api
dotnet user-secrets set "Brusca:DatabaseConnectionString" "Server=.;Database=BruscaDb;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=True;"
```

### 3.2 Anthropic Claude API key

```powershell
dotnet user-secrets set "Brusca:Claude:ApiKey" "sk-ant-…"
```

### 3.3 JWT signing key (when `Brusca:Auth:Mode = Local`)

```powershell
dotnet user-secrets set "Brusca:Auth:Jwt:SecretKey" "$(([guid]::NewGuid().ToString('N')) + ([guid]::NewGuid().ToString('N')))"
```

For Active Directory mode (`Brusca:Auth:Mode = ActiveDirectory`) populate `Brusca:Auth:AzureAd:TenantId` and `Brusca:Auth:AzureAd:ClientId` instead.

---

## 4. Apply the database schema

Run the legacy schema (`cleaning.usp_Cleaning_*`, `cleaning.usp_PromptStep_*`, etc.) plus the **new** PII tables described in `Brusca.Core/docs/DeveloperGuide.md` §5:

- `cleaning.RedactedFile`
- `cleaning.StructurePlan`
- `cleaning.FileRelocation`

…and the matching `usp_RedactedFile_*`, `usp_StructurePlan_*`, `usp_FileRelocation_*` stored procedures.

---

## 5. Configure PII options

`appsettings.json` (or `appsettings.Production.json`) — verify the new `Brusca:Pii` block matches your policy:

```json
"Brusca": {
  "Pii": {
    "Enabled": true,
    "DataProtectionApplicationName": "Brusca.Pii",
    "KeyRingDirectory": null,
    "MaxRedactedContentChars": 4000,
    "Detectors": { "PersonName": true, "EmailAddress": true, "PhoneNumber": true, "SocialSecurityNumber": true, "CreditCardNumber": true, "BankAccountNumber": true, "DateOfBirth": true, "StreetAddress": true, "IpAddress": true, "DriversLicense": true, "PassportNumber": true, "TaxId": true, "MedicalRecordNumber": true, "VehicleIdentificationNumber": true },
    "CustomRules": []
  }
}
```

For multi-instance deployments configure `KeyRingDirectory` to a shared, secured location (or replace `IDataProtectionProvider` with a vault-backed implementation in your composition root).

---

## 6. Run

```powershell
dotnet run --project Brusca.Api/Brusca.Api.csproj
```

The OpenAPI/Scalar UI is available at `/scalar/v1` in development. The `/health` endpoint reports SQL connectivity.

---

## 7. Smoke-test the new endpoints

```powershell
$base = "http://localhost:5000/api"
$id   = (Invoke-RestMethod "$base/cleanings" -Method POST -ContentType application/json `
            -Body (@{ rootPath = "C:\samples"; notes = "smoke" } | ConvertTo-Json)).data.id

Invoke-RestMethod "$base/cleanings/$id/scan"               -Method POST | Out-Null
Invoke-RestMethod "$base/cleanings/$id/redact"             -Method POST
Invoke-RestMethod "$base/cleanings/$id/generate-structure" -Method POST
Invoke-RestMethod "$base/cleanings/$id/set-execution-target" -Method POST -ContentType application/json `
    -Body (@{ target = "AlternatePath"; alternatePath = "C:\samples-out" } | ConvertTo-Json)
Invoke-RestMethod "$base/cleanings/$id/execute-structure"  -Method POST
Invoke-RestMethod "$base/cleanings/$id/relocations"        -Method GET
```

Every step should return `success=true`. The final call returns the before/after relocation log.
