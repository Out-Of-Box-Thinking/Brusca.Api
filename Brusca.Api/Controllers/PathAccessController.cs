using Brusca.Api.DTOs.Response;
using Brusca.Core.Contracts.Services;
using Brusca.Core.Models.PathAccess;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Brusca.Api.Controllers;

/// <summary>
/// Path reachability + remote-share credential management for a Cleaning.
///
/// Three classes of path are recognised:
///   1. Server-local            — accessible directly. No credentials.
///   2. Reachable remote share  — UNC/SMB. May need credentials.
///   3. Client-local            — lives on the user's browser machine and is
///                                NOT reachable from the server. The UI must
///                                refuse to proceed and ask the user to share
///                                the folder over SMB/NFS or upload it.
///
/// Credentials are written over TLS, encrypted by <c>IEncryptionService</c>
/// (same key that seals the PII column), scoped to one Cleaning, and purged
/// when the Cleaning is archived. Cleartext passwords are NEVER persisted
/// and NEVER logged.
/// </summary>
[ApiController]
[Route("api/cleanings/{cleaningId:guid}/path")]
[Authorize]
[RequireHttps]
public sealed class PathAccessController : ControllerBase
{
    private readonly IPathAccessService _service;

    public PathAccessController(IPathAccessService service)
    {
        _service = service;
    }

    /// <summary>
    /// Probe a path's reachability from the server. Returns flags the UI uses
    /// to decide between (proceed / prompt-for-credentials / refuse).
    /// </summary>
    [HttpPost("probe")]
    [ProducesResponseType<ApiResult<PathProbeResult>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Probe(
        [FromRoute] Guid cleaningId,
        [FromBody]  PathProbeRequest request,
        CancellationToken ct)
    {
        var result = await _service.ProbeAsync(request.Path, ct);
        if (result.IsFailed)
            return BadRequest(new ApiResult<PathProbeResult>(
                false, default, result.Errors.Select(e => e.Message).ToList()));
        return Ok(new ApiResult<PathProbeResult>(true, result.Value, null));
    }

    /// <summary>
    /// Save encrypted credentials for the given remote-share root path.
    /// The plaintext password lives only in the request body (TLS-only) and
    /// is encrypted by the server before persisting. There is no read-back.
    /// </summary>
    [HttpPost("credentials")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> SaveCredentials(
        [FromRoute] Guid cleaningId,
        [FromBody]  PathCredentialsRequest request,
        CancellationToken ct)
    {
        var creds = new PathCredentials
        {
            Username = request.Username,
            Password = request.Password,
            Domain   = request.Domain,
        };
        var result = await _service.SaveCredentialsAsync(cleaningId, request.Path, creds, ct);
        if (result.IsFailed)
            return BadRequest(new ApiResult<object>(
                false, default, result.Errors.Select(e => e.Message).ToList()));
        return NoContent();
    }

    /// <summary>
    /// Remove every saved credential for the cleaning. Idempotent.
    /// </summary>
    [HttpDelete("credentials")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> PurgeCredentials(
        [FromRoute] Guid cleaningId, CancellationToken ct)
    {
        var result = await _service.PurgeCredentialsAsync(cleaningId, ct);
        if (result.IsFailed)
            return BadRequest(new ApiResult<object>(
                false, default, result.Errors.Select(e => e.Message).ToList()));
        return NoContent();
    }
}

/// <summary>Body for <c>POST /path/probe</c>.</summary>
public sealed record PathProbeRequest(string Path);

/// <summary>
/// Body for <c>POST /path/credentials</c>. The plaintext <see cref="Password"/>
/// is consumed once, encrypted, and never echoed back.
/// </summary>
public sealed record PathCredentialsRequest(
    string Path,
    string Username,
    string Password,
    string? Domain);
