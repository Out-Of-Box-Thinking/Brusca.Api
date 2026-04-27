using Brusca.Core.Contracts.Logging;
using System.Net;
using System.Text.Json;

namespace Brusca.Api.Middleware;

/// <summary>
/// Injects a X-Correlation-Id header on every request for end-to-end tracing.
/// </summary>
public sealed class CorrelationIdMiddleware
{
    private const string HeaderName = "X-Correlation-Id";
    private readonly RequestDelegate _next;

    public CorrelationIdMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context)
    {
        if (!context.Request.Headers.TryGetValue(HeaderName, out var existing) ||
            string.IsNullOrWhiteSpace(existing))
        {
            context.Request.Headers[HeaderName] = Guid.NewGuid().ToString();
        }

        context.Response.Headers[HeaderName] = context.Request.Headers[HeaderName];
        await _next(context);
    }
}

/// <summary>
/// Catches unhandled exceptions and returns a structured JSON error response.
/// Also logs via IErrorLogger so the configured sink (DB/file/ES) receives it.
/// </summary>
public sealed class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IErrorLogger _log;

    public GlobalExceptionMiddleware(RequestDelegate next, IErrorLogger log)
    {
        _next = next;
        _log = log;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            var correlationId = context.Request.Headers["X-Correlation-Id"].FirstOrDefault();
            await _log.LogErrorAsync("Unhandled exception", ex, correlationId);

            context.Response.StatusCode = (int)HttpStatusCode.InternalServerError;
            context.Response.ContentType = "application/json";

            var body = JsonSerializer.Serialize(new
            {
                error = "An unexpected error occurred.",
                correlationId,
                traceId = context.TraceIdentifier
            });

            await context.Response.WriteAsync(body);
        }
    }
}
