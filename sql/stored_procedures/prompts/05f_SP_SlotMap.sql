-- =============================================================================
-- 05f_SP_SlotMap.sql
-- Phase 11: per-file PII slot mapping. Updates the plaintext SlotMapJson
-- column on [cleaning].[RedactedFile] after the slot-mapping service has
-- correlated each rule's RequiredTokenSlots to a PiiSegment.Ordinal.
-- =============================================================================

USE [BruscaDb];
GO

CREATE OR ALTER PROCEDURE [cleaning].[usp_RedactedFile_UpdateSlotMap]
    @Id          UNIQUEIDENTIFIER,
    @SlotMapJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE [cleaning].[RedactedFile]
    SET    [SlotMapJson] = @SlotMapJson
    WHERE  [Id] = @Id;
END;
GO

PRINT '05f_SP_SlotMap.sql complete.';
