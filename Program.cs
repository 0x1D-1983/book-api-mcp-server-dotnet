using ModelContextProtocol.Server;
using System.ComponentModel;
using BookApiMcpServer.Services;
using BookApiMcpServer.Models;

var builder = WebApplication.CreateBuilder(args);

var serverUrl = "http://localhost:5288/";

builder.Logging.AddConsole(options =>
{
    // Configure all logs to go to stderr
    options.LogToStandardErrorThreshold = LogLevel.Trace;
});

builder.Services.AddHttpContextAccessor();
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

app.MapMcp();

await app.RunAsync(serverUrl);