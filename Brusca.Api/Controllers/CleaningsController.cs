using Brusca.Api.DTOs.Request;
using Brusca.Api.DTOs.Response;
using Brusca.Core.Contracts.Repositories;
using Brusca.Core.Contracts.Services;
using Brusca.Core.Enums;
using Brusca.Core.Models.Cleaning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Brusca.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class CleaningsController : ControllerBase
{
    private readonly ICleaningService _service;
    private readonly IPromptStepCommandRepository _cmdRepo;

    public CleaningsController(
        ICleaningService service,
        IPromptStepCommandRepository cmdRepo)
    {
        _service = service;
        _cmdRepo = cmdRepo;
    }

    private string UserId => User.FindFirst("sub")?.Value ?? "unknown";

    /// <summary>Start a new Cleaning run.</summary>
    [HttpPost]
    [ProducesResponseType<ApiResult<CleaningResponse>>(StatusCodes.Status201Created)]
    public async Task<IActionResult> Start(
        [FromBody] StartCleaningRequest request, CancellationToken ct)
    {
        var result = await _service.StartCleaningAsync(request.RootPath, UserId, ct);
        if (result.IsFailed)
            return BadRequest(Fail<CleaningResponse>(result.Errors));
        return CreatedAtAction(nameof(GetById), new { id = result.Value.Id },
            Ok(MapToResponse(result.Value)));
    }

    /// <summary>Get a Cleaning by ID.</summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType<ApiResult<CleaningResponse>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetById(Guid id, CancellationToken ct)
    {
        var result = await _service.GetCleaningAsync(id, ct);
        if (result.IsFailed) return NotFound();
        return Ok(Ok(MapToResponse(result.Value)));
    }

    /// <summary>Scan the path for file extensions.</summary>
    [HttpPost("{id:guid}/scan")]
    [ProducesResponseType<ApiResult<ExtensionScanResponse>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Scan(Guid id, CancellationToken ct)
    {
        var result = await _service.ScanExtensionsAsync(id, ct);
        if (result.IsFailed)
            return BadRequest(Fail<ExtensionScanResponse>(result.Errors));

        return Ok(new ApiResult<ExtensionScanResponse>(true,
            new ExtensionScanResponse(
                result.Value.AllExtensions,
                result.Value.UnknownExtensions,
                result.Value.TotalFileCount,
                result.Value.TotalDirectoryCount), null));
    }

    /// <summary>Generate Claude prompt steps (with C#/CMD/PowerShell commands).</summary>
    [HttpPost("{id:guid}/generate-steps")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> GenerateSteps(Guid id, CancellationToken ct)
    {
        var result = await _service.GeneratePromptStepsAsync(id, ct);
        if (result.IsFailed)
            return BadRequest(Fail<object>(result.Errors));
        return NoContent();
    }

    /// <summary>
    /// Set the execution target.
    /// If Target == "SourcePath" the UI must first present the source-path warning,
    /// and should call POST .../confirm-source before this endpoint.
    /// </summary>
    [HttpPost("{id:guid}/set-execution-target")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> SetExecutionTarget(
        Guid id,
        [FromBody] SetExecutionTargetRequest request,
        CancellationToken ct)
    {
        if (!Enum.TryParse<ExecutionTarget>(request.Target, out var target))
            return BadRequest(Fail<object>(["Invalid ExecutionTarget value."]));

        if (target == ExecutionTarget.AlternatePath &&
            string.IsNullOrWhiteSpace(request.AlternatePath))
            return BadRequest(Fail<object>(["AlternatePath is required when Target is AlternatePath."]));

        var result = await _service.SetExecutionTargetAsync(
            id, target, request.AlternatePath, UserId, ct);
        if (result.IsFailed)
            return BadRequest(Fail<object>(result.Errors));
        return NoContent();
    }

    /// <summary>Execute all approved steps against the configured execution target.</summary>
    [HttpPost("{id:guid}/execute")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Execute(Guid id, CancellationToken ct)
    {
        var result = await _service.ExecuteApprovedStepsAsync(id, ct);
        if (result.IsFailed)
            return BadRequest(Fail<object>(result.Errors));
        return NoContent();
    }

    /// <summary>
    /// Restart a halted Cleaning from the beginning.
    /// Deletes all steps, commands, and tree snapshots so the Cleaning
    /// can be re-scanned cleanly.
    /// </summary>
    [HttpPost("{id:guid}/restart")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Restart(Guid id, CancellationToken ct)
    {
        var result = await _service.RestartCleaningAsync(id, UserId, ct);
        if (result.IsFailed)
            return BadRequest(Fail<object>(result.Errors));
        return NoContent();
    }

    /// <summary>
    /// Get the before/after directory tree comparison.
    /// The "after" tree is projected from approved steps while the Cleaning
    /// is in PromptGenerated status; after execution it reflects the actual result.
    /// </summary>
    [HttpGet("{id:guid}/tree-comparison")]
    [ProducesResponseType<ApiResult<TreeComparisonResponse>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetTreeComparison(Guid id, CancellationToken ct)
    {
        var result = await _service.GetTreeComparisonAsync(id, ct);
        if (result.IsFailed) return NotFound();

        return Ok(new ApiResult<TreeComparisonResponse>(true,
            new TreeComparisonResponse(
                result.Value.CleaningId,
                MapNode(result.Value.BeforeTree),
                MapNode(result.Value.AfterTree),
                result.Value.TotalRenames,
                result.Value.TotalMoves,
                result.Value.IsAfterProjected), null));
    }

    // ── Mapping helpers ───────────────────────────────────────────────────────

    private static ApiResult<T> Ok<T>(T data) => new(true, data, null);
    private static ApiResult<T> Fail<T>(IEnumerable<FluentResults.IError> errors) =>
        new(false, default, errors.Select(e => e.Message).ToList());
    private static ApiResult<T> Fail<T>(IReadOnlyList<string> errors) =>
        new(false, default, errors);

    private static CleaningResponse MapToResponse(Cleaning c) =>
        new(c.Id, c.RootPath, c.Status.ToString(),
            c.CreatedAtUtc, c.CompletedAtUtc,
            c.RestartCount,
            c.ExecutionTarget.ToString(),
            c.AlternateExecutionPath,
            c.FileExtensions.Sum(e => e.FileCount),
            c.FileExtensions.Select(e => new ExtensionResponse(
                e.Extension, e.FileCount, e.Status.ToString(),
                e.SuggestedNuGetPackage)).ToList(),
            c.PromptSteps.Select(MapStep).ToList());

    private static PromptStepResponse MapStep(CleaningPromptStep s) =>
        new(s.Id, s.StepOrder, s.StepType.ToString(),
            s.PromptText, s.GeneratedResponse,
            s.SourcePath, s.ProposedTargetPath,
            s.IsApproved, s.IsExecuted, s.ExecutionError,
            s.Commands.Select(MapCommand).ToList());

    private static PromptStepCommandResponse MapCommand(PromptStepCommand c) =>
        new(c.Id, c.PromptStepId, c.Language.ToString(),
            c.CommandBody, c.CommandOrder, c.IsExecuted, c.ExecutionError);

    private static TreeNodeResponse? MapNode(Core.Models.Cleaning.DirectoryNode? n)
    {
        if (n is null) return null;
        return new TreeNodeResponse(
            n.FullPath, n.Name, n.Depth, n.FileCount,
            n.Extensions, n.Files,
            n.Children.Select(MapNode).Where(x => x is not null)
                       .Select(x => x!).ToList());
    }
}
