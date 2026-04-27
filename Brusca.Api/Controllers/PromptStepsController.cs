using Brusca.Api.DTOs.Response;
using Brusca.Core.Contracts.Repositories;
using Brusca.Core.Models.Cleaning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Brusca.Api.Controllers;

[ApiController]
[Route("api/cleanings/{cleaningId:guid}/steps")]
[Authorize]
public sealed class PromptStepsController : ControllerBase
{
    private readonly IPromptStepRepository _stepRepo;
    private readonly IPromptStepCommandRepository _cmdRepo;

    public PromptStepsController(
        IPromptStepRepository stepRepo,
        IPromptStepCommandRepository cmdRepo)
    {
        _stepRepo = stepRepo;
        _cmdRepo  = cmdRepo;
    }

    /// <summary>Get all prompt steps for a Cleaning, ordered by StepOrder, with commands.</summary>
    [HttpGet]
    [ProducesResponseType<ApiResult<IReadOnlyList<PromptStepResponse>>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAll(Guid cleaningId, CancellationToken ct)
    {
        var stepsResult = await _stepRepo.GetByCleaningIdAsync(cleaningId, ct);
        if (stepsResult.IsFailed)
            return BadRequest(new ApiResult<object>(false, null,
                stepsResult.Errors.Select(e => e.Message).ToList()));

        // Hydrate commands for all steps in a single query
        var allCmds = await _cmdRepo.GetByCleaningIdAsync(cleaningId, ct);
        var cmdsByStep = allCmds.IsSuccess
            ? allCmds.Value.GroupBy(c => c.PromptStepId)
                           .ToDictionary(g => g.Key, g => g.ToList())
            : new Dictionary<Guid, List<PromptStepCommand>>();

        var response = stepsResult.Value
            .OrderBy(s => s.StepOrder)
            .Select(s =>
            {
                var cmds = cmdsByStep.TryGetValue(s.Id, out var c) ? c : [];
                return new PromptStepResponse(
                    s.Id, s.StepOrder, s.StepType.ToString(),
                    s.PromptText, s.GeneratedResponse,
                    s.SourcePath, s.ProposedTargetPath,
                    s.IsApproved, s.IsExecuted, s.ExecutionError,
                    cmds.OrderBy(c => c.CommandOrder)
                        .Select(c => new PromptStepCommandResponse(
                            c.Id, c.PromptStepId, c.Language.ToString(),
                            c.CommandBody, c.CommandOrder, c.IsExecuted, c.ExecutionError))
                        .ToList());
            }).ToList();

        return Ok(new ApiResult<IReadOnlyList<PromptStepResponse>>(true, response, null));
    }

    /// <summary>Approve a prompt step so it will be included in execution.</summary>
    [HttpPost("{stepId:guid}/approve")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Approve(Guid cleaningId, Guid stepId, CancellationToken ct)
    {
        var result = await _stepRepo.ApproveStepAsync(stepId, ct);
        if (result.IsFailed)
            return BadRequest(new ApiResult<object>(false, null,
                result.Errors.Select(e => e.Message).ToList()));
        return NoContent();
    }
}
