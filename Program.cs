using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using ModelContextProtocol.Server;
using Serilog;
using System.ComponentModel;
using BookApiMcpServer.Services;
using BookApiMcpServer.Models;

var builder = Host.CreateApplicationBuilder(args);

// Configure Serilog and clear existing log providers
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .CreateLogger();

builder.Services.AddSerilog();

try
{
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
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}

