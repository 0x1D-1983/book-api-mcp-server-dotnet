using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using ModelContextProtocol.Server;
using System.ComponentModel;
using BookApiMcpServer.Services;
using BookApiMcpServer.Models;

var builder = Host.CreateApplicationBuilder(args);

builder.Logging.AddConsole(options =>
{
    // Configure all logs to go to stderr
    options.LogToStandardErrorThreshold = LogLevel.Trace;
});

builder.Services
        .AddMcpServer()
        .WithStdioServerTransport()
        .WithToolsFromAssembly();

// Configure BookApiConfig using IOptionsMonitor
builder.Services.Configure<BookApiConfig>(
    builder.Configuration.GetSection("BookApi"));

builder.Services.AddHttpClient();
builder.Services.AddSingleton<BookService>();

await builder.Build().RunAsync();