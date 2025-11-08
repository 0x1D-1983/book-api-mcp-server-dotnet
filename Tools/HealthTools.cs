namespace BookApiMcpServer.Tools;

using ModelContextProtocol.Server;
using System.ComponentModel;

[McpServerToolType]
public static class HealthTools
{
    [McpServerTool, Description("Get the health of the server")]
    public static string GetHealth()
    {
        return "Healthy";
    }
}