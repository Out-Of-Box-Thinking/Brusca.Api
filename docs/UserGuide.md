# Brusca User Guide

Brusca is an AI-powered file organization tool. You point it at a folder — on your local machine or a network share — and it analyzes the files, generates a set of rename and reorganization steps (with executable commands in C#, CMD, and PowerShell), lets you review and approve each change, then applies them.

---

## Getting started

Open Brusca in your browser at the URL your administrator provided (e.g. `https://brusca-app.yourdomain.com`). You will be asked to log in with your username and password.

---

## The cleaning workflow

A single run from scan to execution is called a **Cleaning**. The workflow has five stages shown at the top of each Cleaning card.

```
Pending → Scanning → Analyzing → Prompt Generated → Executing → Completed
```

If a file type cannot be read, the status changes to **Awaiting Extension Resolution** — see the section on unknown file types below.

---

## Starting a new cleaning

1. On the **Cleanings** page, enter the path you want to organize in the text box.
   - Local path: `C:\Users\YourName\Documents\Projects`
   - Network share: `\\fileserver\departments\finance`
2. Click **Start cleaning**.

The Cleaning card appears with status **Pending**.

---

## Step 1 — Scan extensions

Click **Scan extensions**. Brusca walks the entire directory tree and records every file extension it finds.

- All discovered extensions appear as colored badges.
- Extensions with no registered reader appear in **amber with a ⚠ warning**.

### If unknown extensions are found

A modal appears for each unknown extension. For each one:

1. Enter the name of the NuGet package that provides read access for that file type (e.g. `ExcelDataReader` for `.xls` files, `DocumentFormat.OpenXml` for custom XML variants).
2. Click **Register & continue**.

> **Note:** Registering a NuGet package records the name for the development team to implement. The Cleaning cannot continue until all unknown extensions are resolved, the new reader is added to the application, and the application is recompiled and redeployed. Contact your administrator or development team.

After registering all packages, click **↺ Restart from beginning** to re-scan with the new readers in place.

---

## Step 2 — Generate steps

Click **Generate steps**. Brusca reads a sample of the files in the path and sends the directory structure to Claude (Anthropic's AI) for analysis.

Claude returns an ordered list of rename and reorganization steps. For each step, three executable commands are generated — C#, CMD, and PowerShell — so the operation can be performed on any Windows environment.

When generation is complete, the card switches to the **Steps** tab automatically.

---

## Step 3 — Review the before/after tree

Click the **Before / After tree** tab to see a side-by-side view of your directory as it is today (Before) and how it will look after all approved steps are applied (After).

- **Amber nodes** — directories or files that will be renamed
- **Blue nodes** — files that will be moved to a different location
- **Green badge** — executed (shown after a Cleaning completes)
- **Projected badge** — the After tree is a preview, not yet applied

Expand any folder in either panel by clicking it. File names within each directory are also listed.

---

## Step 4 — Review and approve steps

Back on the **Steps** tab, each step shows:

- The step type (Directory rename, File rename, File move, etc.)
- The source path and proposed target path
- Claude's rationale for the change
- The step GUID (for audit reference)

To see the executable commands, click the **commands link** under each step. A tabbed viewer shows the C#, CMD, and PowerShell versions of the command. Each command also has its own GUID shown in the top-right corner of the viewer.

Click **Approve** on each step you want to include in execution. You can approve as many or as few as you like. Steps you leave unapproved will be skipped.

---

## Step 5 — Choose where to apply changes

Before executing, click **Set execution target** to choose where Brusca will apply the changes.

### Alternate path (recommended)

Enter a different directory path. Brusca will apply all renames and moves there instead of touching your original files. This is the safest option — you can verify the result before committing.

### Source path

Changes are applied directly to the original path you entered when starting the Cleaning. Because this is permanent and cannot be undone by Brusca:

1. A warning screen describes exactly what will happen and lists the source path.
2. After clicking **I understand — proceed**, a second confirmation asks "Are you absolutely sure?"
3. Only after the second confirmation is the source path set as the target.

The **Execute** button turns **red** when the source path is selected as a reminder that changes will affect your original files.

> **Recommendation:** Always test with an alternate path first. Once you are satisfied with the result, you can run the same Cleaning against the source path.

---

## Step 6 — Execute

Click **Execute**. All approved steps run in order. The status changes to **Executing**, then **Completed**.

After execution:

- Each step shows ✓ Executed or ✗ with an error message
- The Before / After tree updates to show the actual result
- A full audit trail is written to the database

---

## Restarting a halted cleaning

If a Cleaning is stuck at **Awaiting Extension Resolution** or **Failed**, click **↺ Restart from beginning**.

This clears:
- All scan data (file extensions discovered in this run)
- All generated steps and commands
- The before/after tree snapshots

The Cleaning keeps its ID and root path so it appears in your history. The restart count is shown on the card (e.g. "↺ 2× restarted").

After restarting, click **Scan extensions** to begin again.

---

## The Extensions page

Navigate to **Extensions** in the top menu to see all file types ever encountered across all Cleanings. Use the filter buttons to show only unknown extensions.

For each extension you can see:

- Status (Known, Unknown, Pending package)
- The NuGet package registered for it
- How many times it has been seen
- When it was last encountered

---

## Understanding the step commands

Each step generates three commands automatically. You do not need to run these yourself — Brusca runs them for you during execution. They are shown so you can:

- Understand exactly what Brusca will do before approving
- Copy and run them manually if you prefer to apply changes outside Brusca
- Reference them in the audit log by their GUID

### Command languages

| Language | When to use manually |
|----------|---------------------|
| **C#** | In a .NET script or LINQPad |
| **CMD** | In a Windows command prompt (`cmd.exe`) |
| **PowerShell** | In a PowerShell terminal (recommended for most manual use) |

Example PowerShell command for a file rename:

```powershell
Rename-Item -Path "C:\Files\2023 budget final FINAL v3.xlsx" `
            -NewName "2023-Budget-Final.xlsx"
```

---

## Frequently asked questions

**Can I approve only some steps and skip others?**
Yes. Only steps you click Approve on will be executed. Unapproved steps are permanently skipped for that run. They remain visible in the history.

**What happens if a step fails during execution?**
The step is marked with ✗ and the error message. Brusca continues to the next approved step. Failed steps can be reviewed and the commands can be run manually.

**Can I run the same path again?**
Yes — start a new Cleaning with the same path. Each Cleaning is independent.

**Will Brusca delete any files?**
No. Brusca only renames and moves files. It never deletes anything.

**Can I undo a completed Cleaning?**
Brusca does not have an undo feature. This is why the alternate path option exists — use it to apply changes to a copy first. If you applied to the source path and want to revert, the original commands (shown in the step viewer) can be reversed manually.

**Is my file content sent to Claude?**
A sample of text from up to five files is sent to Anthropic's API to help Claude understand what the files contain and generate better naming suggestions. Only text content is sampled — binary files are skipped. If you have data privacy concerns, discuss with your administrator whether to enable or disable file content sampling.


---

## PII redaction & structure planning (NEW)

The cleaning pipeline now includes three additional endpoints that redact PII before
ever calling Claude and apply a Claude-designed directory layout to the chosen execution target.

### POST /api/cleanings/{id}/redact

Reads every supported file under the root path, strips PII, classifies the document type, and persists a redacted descriptor with an encrypted PII column.

Response: `ApiResult<RedactionSummaryResponse>` containing per-bucket counts grouped by `(documentType, extension)`. **No PII is returned.**

### POST /api/cleanings/{id}/generate-structure

Sends ONLY the bucket counts to Claude, asks it to design a directory layout, and persists the resulting plan.

Response: `ApiResult<StructurePlanResponse>`.

### GET /api/cleanings/{id}/structure-plan

Returns the latest plan for the cleaning.

### POST /api/cleanings/{id}/execute-structure

Applies the plan against the configured execution target. Decrypts the PII column **in memory only** to substitute template tokens, performs the move/rename/create, and records before/after state.

Response: `ApiResult<FileRelocationResponse[]>`.

### GET /api/cleanings/{id}/relocations

Returns the full before/after relocation log for the cleaning. This is the audit-grade record of what changed.

### Privacy guarantees

1. The original PII text only ever lives in memory inside `RegexPiiRedactionService` and `StructureExecutionService.BuildTokenMap`.
2. At rest, PII is sealed in `cleaning.RedactedFile.EncryptedPiiJson` via ASP.NET Core Data Protection.
3. Claude is called with anonymized aggregates only \u2014 no file names, no content, no PII.
4. Every move/rename/create is recorded with a `BeforePath`/`BeforeName` and `AfterPath`/`AfterName` for full traceability whether the execution target is the source path or an alternate path.
