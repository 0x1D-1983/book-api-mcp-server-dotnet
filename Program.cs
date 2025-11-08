using Microsoft.AspNetCore.Http;
using ModelContextProtocol.Server;
using BookApiMcpServer.Services;
using BookApiMcpServer.Models;
using ModelContextProtocol.AspNetCore.Authentication;

var builder = WebApplication.CreateBuilder(args);

builder.Logging.AddConsole(options =>
{
    // Configure all logs to go to stderr
    options.LogToStandardErrorThreshold = LogLevel.Trace;
});

builder.Services
        .AddMcpServer()
        .WithHttpTransport()
        .WithToolsFromAssembly();

// Configure BookApiConfig using IOptionsMonitor
builder.Services.Configure<BookApiConfig>(
    builder.Configuration.GetSection("BookApi"));

builder.Services.AddHttpClient();
builder.Services.AddSingleton<BookService>();

var app = builder.Build();

app.MapMcp("/{toolCategory?}");
app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

await app.RunAsync("http://0.0.0.0:5289");