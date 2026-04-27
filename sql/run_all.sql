-- =============================================================================
-- run_all.sql  (RE-RUNNABLE / IDEMPOTENT)
-- Executes all BruscaDb setup scripts in the correct order.
-- Safe to re-run on any environment — all scripts guard against duplication.
--
-- Usage from the solution root:
--   sqlcmd -S <server> -E -i sql\run_all.sql
--   sqlcmd -S <server> -U sa -P <password> -i sql\run_all.sql
--
-- Adjust the -S parameter to your SQL Server instance name.
-- For a named instance: -S SERVER\INSTANCENAME
-- =============================================================================

:r sql\filegroups\01_CreateDatabase.sql
:r sql\schemas\02_CreateSchemas.sql
:r sql\tables\03_CreateTables.sql
:r sql\tables\03b_AlterTables_NewFeatures.sql
:r sql\indexes\04_CreateIndexes.sql
:r sql\stored_procedures\cleaning\05a_SP_Cleaning.sql
:r sql\stored_procedures\fileext\05b_SP_FileExt_Prompts.sql
:r sql\stored_procedures\security\05c_SP_Security.sql
:r sql\stored_procedures\prompts\05d_SP_NewFeatures.sql
:r sql\security\06_Security.sql

PRINT '';
PRINT '============================================================';
PRINT 'BruscaDb setup complete. All scripts ran successfully.';
PRINT '============================================================';
GO
