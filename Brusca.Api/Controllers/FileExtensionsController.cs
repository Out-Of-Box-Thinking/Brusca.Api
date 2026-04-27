using Brusca.Api.DTOs.Request;
using Brusca.Api.DTOs.Response;
using Brusca.Core.Contracts.Services;
using Brusca.Core.Models.Extensions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Brusca.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class FileExtensionsController : ControllerBase
{
    private readonly IFileExtensionService _service;

    public FileExtensionsController(IFileExtensionService service) => _service = service;

    /// <summary>Get the master file extension list.</summary>
    [HttpGet]
    [ProducesResponseType<ApiResult<IReadOnlyList<FileExtensionRecord>>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAll(CancellationToken ct)
    {
        var result = await _service.GetMasterListAsync(ct);
        if (result.IsFailed)
            return BadRequest(new ApiResult<object>(false, null,
                result.Errors.Select(e => e.Message).ToList()));
        return Ok(new ApiResult<IReadOnlyList<FileExtensionRecord>>(true, result.Value, null));
    }

    /// <summary>
    /// Register a NuGet package that handles an unknown extension.
    /// This is called from the UI popup that blocks app operation when an
    /// unknown extension is encountered.
    /// </summary>
    [HttpPost("register-package")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> RegisterPackage(
        [FromBody] RegisterExtensionPackageRequest request,
        CancellationToken ct)
    {
        var result = await _service.RegisterPackageForExtensionAsync(
            request.Extension, request.NuGetPackage, ct);
        if (result.IsFailed)
            return BadRequest(new ApiResult<object>(false, null,
                result.Errors.Select(e => e.Message).ToList()));
        return NoContent();
    }
}
