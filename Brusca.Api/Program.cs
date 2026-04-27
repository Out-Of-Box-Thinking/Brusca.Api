using Brusca.Api.Middleware;
using Brusca.Core.Enums;
using Brusca.Core.Models;
using Brusca.Infrastructure.Configuration;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Scalar.AspNetCore;
using Serilog;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// ── Logging ───────────────────────────────────────────────────────────────────
builder.Host.UseSerilog();

// ── Options ───────────────────────────────────────────────────────────────────
var bruscaOpts = builder.Configuration.GetSection("Brusca").Get<BruscaOptions>() ?? new();

// ── Validate required configuration ──────────────────────────────────────────
if (string.IsNullOrWhiteSpace(bruscaOpts.DatabaseConnectionString))
    throw new InvalidOperationException(
        "Brusca:DatabaseConnectionString is required. " +
        "Set it in appsettings.json, User Secrets (dev), or environment variables (production). " +
        "See docs/SetupGuide.md for instructions.");

// ── Infrastructure (repositories, services, logging) ─────────────────────────
builder.Services.AddBruscaInfrastructure(builder.Configuration);

// ── Authentication ─────────────────────────────────────────────────────────── 
if (bruscaOpts.Auth.Mode == AuthenticationMode.ActiveDirectory)
{
    builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("Brusca:Auth:AzureAd"));
}
else
{
    var jwtOpts = bruscaOpts.Auth.Jwt;
    builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(options =>
        {
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer           = true,
                ValidateAudience         = true,
                ValidateLifetime         = true,
                ValidateIssuerSigningKey = true,
                ValidIssuer              = jwtOpts.Issuer,
                ValidAudience            = jwtOpts.Audience,
                IssuerSigningKey         = new SymmetricSecurityKey(
                    Encoding.UTF8.GetBytes(jwtOpts.SecretKey))
            };
        });
}

builder.Services.AddAuthorization();

// ── MVC / API ─────────────────────────────────────────────────────────────────
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// ── OpenAPI (Scalar) ──────────────────────────────────────────────────────────
builder.Services.AddOpenApi();

// ── Health checks ─────────────────────────────────────────────────────────────
builder.Services.AddHealthChecks()
    .AddSqlServer(
        bruscaOpts.DatabaseConnectionString,   // Single connection string source
        name: "sql-server",
        tags: ["db", "ready"]);

// ── CORS ──────────────────────────────────────────────────────────────────────
// Allowed origins: read from configuration so they can be overridden per environment.
// In production, set Brusca:Cors:AllowedOrigins in appsettings.Production.json
// or via the Brusca__Cors__AllowedOrigins environment variable.
var allowedOrigins = builder.Configuration
    .GetSection("Brusca:Cors:AllowedOrigins")
    .Get<string[]>()
    ?? ["http://localhost:4321", "http://localhost:3000"];

builder.Services.AddCors(opts =>
    opts.AddPolicy("AstroUi", policy =>
        policy.WithOrigins(allowedOrigins)
              .AllowAnyHeader()
              .AllowAnyMethod()));

// ── Rate limiting ─────────────────────────────────────────────────────────────
builder.Services.AddRateLimiter(opts =>
    opts.AddFixedWindowLimiter("default", limiter =>
    {
        limiter.Window      = TimeSpan.FromSeconds(10);
        limiter.PermitLimit = 100;
    }));

var app = builder.Build();

// ── Middleware pipeline ────────────────────────────────────────────────────────
app.UseMiddleware<CorrelationIdMiddleware>();
app.UseMiddleware<GlobalExceptionMiddleware>();

app.UseSerilogRequestLogging();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseCors("AstroUi");
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.MapHealthChecks("/health");

app.Run();
