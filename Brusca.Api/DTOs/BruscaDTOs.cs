// Request and Response DTOs for the Brusca API.

namespace Brusca.Api.DTOs.Request
{
    public sealed record StartCleaningRequest(string RootPath, string? Notes);
    public sealed record ApproveStepRequest(System.Guid StepId);
    public sealed record RegisterExtensionPackageRequest(string Extension, string NuGetPackage);

    /// <summary>
    /// Set where the Cleaning's file operations will be applied.
    /// If Target == AlternatePath then AlternatePath must be populated.
    /// </summary>
    public sealed record SetExecutionTargetRequest(
        string Target,
        string? AlternatePath);
}

namespace Brusca.Api.DTOs.Response
{
    using System;
    using System.Collections.Generic;

    public sealed record CleaningResponse(
        Guid Id,
        string RootPath,
        string Status,
        DateTime CreatedAtUtc,
        DateTime? CompletedAtUtc,
        int RestartCount,
        string ExecutionTarget,
        string? AlternateExecutionPath,
        int TotalFiles,
        IReadOnlyList<ExtensionResponse> Extensions,
        IReadOnlyList<PromptStepResponse> PromptSteps);

    public sealed record ExtensionResponse(
        string Extension,
        int FileCount,
        string Status,
        string? SuggestedNuGetPackage);

    public sealed record PromptStepResponse(
        Guid Id,
        int StepOrder,
        string StepType,
        string PromptText,
        string? GeneratedResponse,
        string? SourcePath,
        string? ProposedTargetPath,
        bool IsApproved,
        bool IsExecuted,
        string? ExecutionError,
        IReadOnlyList<PromptStepCommandResponse> Commands);

    public sealed record PromptStepCommandResponse(
        Guid Id,
        Guid PromptStepId,
        string Language,
        string CommandBody,
        int CommandOrder,
        bool IsExecuted,
        string? ExecutionError);

    public sealed record ExtensionScanResponse(
        IReadOnlyList<string> AllExtensions,
        IReadOnlyList<string> UnknownExtensions,
        int TotalFileCount,
        int TotalDirectoryCount);

    public sealed record TreeNodeResponse(
        string FullPath,
        string Name,
        int Depth,
        int FileCount,
        IReadOnlyList<string> Extensions,
        IReadOnlyList<string> Files,
        IReadOnlyList<TreeNodeResponse> Children);

    public sealed record TreeComparisonResponse(
        Guid CleaningId,
        TreeNodeResponse? BeforeTree,
        TreeNodeResponse? AfterTree,
        int TotalRenames,
        int TotalMoves,
        bool IsAfterProjected);

    public sealed record ApiResult<T>(bool Success, T? Data, IReadOnlyList<string>? Errors);

    // PII / structure-plan response DTOs

    public sealed record RedactedFileResponse(
        Guid Id,
        Guid CleaningId,
        string OriginalFilePath,
        string OriginalFileName,
        string Extension,
        string DocumentType,
        int    PiiSegmentCount,
        string? ContentHash,
        DateTime DiscoveredAtUtc);

    public sealed record RedactionSummaryResponse(
        Guid CleaningId,
        int  TotalFiles,
        IReadOnlyList<DocumentTypeBucketResponse> Buckets);

    public sealed record DocumentTypeBucketResponse(
        string DocumentType,
        string Extension,
        int    Count);

    public sealed record StructurePlanResponse(
        Guid Id,
        Guid CleaningId,
        string Summary,
        DateTime GeneratedAtUtc,
        IReadOnlyList<StructureRuleResponse> Rules);

    public sealed record StructureRuleResponse(
        Guid Id,
        int  Order,
        string DocumentType,
        string Extension,
        string FolderPathTemplate,
        string FileNameTemplate,
        IReadOnlyList<string> RequiredTokenSlots,
        string? Rationale);

    public sealed record FileRelocationResponse(
        Guid Id,
        Guid CleaningId,
        Guid? RedactedFileId,
        string OperationType,
        string ExecutionTarget,
        string? BeforePath,
        string? BeforeName,
        string? AfterPath,
        string? AfterName,
        string Status,
        string? ErrorMessage,
        DateTime CreatedAtUtc,
        DateTime? CompletedAtUtc);
}