# Book API MCP Server (.NET)

A Model Context Protocol (MCP) server implementation in .NET that provides access to a Book API through standardized MCP tools. This server enables AI assistants and other MCP-compatible clients to interact with book data via the MCP protocol.

## Overview

This MCP server acts as a bridge between MCP clients (like Cursor, Claude Desktop, or other AI assistants) and a RESTful Book API. It exposes book management operations as MCP tools, allowing clients to perform CRUD operations on books through the standardized MCP protocol.

The .NET Book API backend that this MCP server interacts with is available at: [https://github.com/0x1D-1983/book-api](https://github.com/0x1D-1983/book-api).

## Features

- ✅ Full CRUD operations for books
- ✅ MCP Protocol 2024-11-05 compliant
- ✅ Structured logging with Serilog
- ✅ Dependency injection and configuration management
- ✅ Type-safe tool definitions with automatic schema generation
- ✅ JSON serialization support

## Prerequisites

- [.NET 10.0 SDK](https://dotnet.microsoft.com/download) or later
- A running Book API instance (default: `http://localhost:5288`)

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd book-api-mcp-server-dotnet
```

2. Restore dependencies:
```bash
dotnet restore
```

3. Build the project:
```bash
dotnet build
```

## Configuration

Edit `appsettings.json` to configure the server:

```json
{
  "BookApi": {
    "BaseUrl": "http://localhost:5288"
  },
  "Serilog": {
    "MinimumLevel": {
      "Default": "Debug"
    }
  }
}
```

### Key Configuration Options

- **BookApi.BaseUrl**: The base URL of the Book API endpoint
- **Serilog**: Logging configuration (see [Serilog documentation](https://github.com/serilog/serilog-settings-configuration))

## Usage with Cursor

To use this MCP server with Cursor, add the following to your `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "book-api-mcp-server-dotnet": {
      "command": "dotnet",
      "args": ["run", "--project", "/path/to/book-api-mcp-server-dotnet/BookApiMcpServer.csproj"],
      "env": {}
    }
  }
}
```

After adding the configuration, restart Cursor to enable the MCP server.

## Available MCP Tools

The server exposes the following tools (automatically converted to snake_case):

### `get_books`
Retrieves all books from the API.

**Parameters:** None

**Returns:** List of books (JSON strings)

### `get_book_by_id`
Retrieves a specific book by its ID.

**Parameters:**
- `id` (integer, required): The book ID

**Returns:** Book object (JSON string)

### `create_book`
Creates a new book.

**Parameters:**
- `book` (object, required): Book object with the following properties:
  - `id` (integer)
  - `title` (string)
  - `author` (string)
  - `isbn` (string)
  - `publishedDate` (string, ISO 8601 datetime)
  - `createdAt` (string, ISO 8601 datetime)

**Returns:** Created book object (JSON string)

### `update_book`
Updates an existing book.

**Parameters:**
- `book` (object, required): Book object with updated properties

**Returns:** Updated book object (JSON string)

### `delete_book`
Deletes a book by ID.

**Parameters:**
- `id` (integer, required): The book ID to delete

**Returns:** Deleted book object (JSON string)

## Architecture

### Project Structure

```
BookApiMcpServer/
├── Models/
│   ├── Book.cs              # Book entity model
│   └── BookApiConfig.cs     # API configuration model
├── Services/
│   └── BookService.cs       # HTTP client service for Book API
├── Tools/
│   └── BookTools.cs         # MCP tool definitions
├── Program.cs               # Application entry point
├── appsettings.json         # Configuration file
└── BookApiMcpServer.csproj  # Project file
```

### Key Components

#### **Program.cs**
- Configures the MCP server with stdio transport
- Sets up dependency injection
- Configures Serilog logging
- Registers MCP tools from the assembly

#### **BookTools.cs**
- Defines MCP tools using `[McpServerTool]` attributes
- Tools are automatically discovered and registered
- Method names are converted to snake_case (e.g., `GetBooks` → `get_books`)
- Descriptions are used for tool documentation

#### **BookService.cs**
- Encapsulates HTTP calls to the Book API
- Uses `HttpClient` for API communication
- Handles JSON serialization/deserialization

#### **Models**
- **Book.cs**: Represents a book entity
- **BookApiConfig.cs**: Configuration model for API settings

### MCP Protocol Integration

The server uses the `ModelContextProtocol` NuGet package to:
- Implement JSON-RPC 2.0 protocol over stdio
- Automatically generate tool schemas from method signatures
- Handle request/response serialization
- Support MCP Protocol Version 2024-11-05

## Dependencies

- **Microsoft.Extensions.Hosting** (9.0.10): Hosting infrastructure
- **ModelContextProtocol** (0.4.0-preview.3): MCP protocol implementation
- **Serilog.AspNetCore** (8.0.3): Structured logging
- **Serilog.Settings.Configuration** (8.0.4): Configuration-based logging setup
- **Serilog.Sinks.Console** (6.0.0): Console logging output

## Testing

The project includes test scripts to verify MCP server functionality:

### Test MCP Connection
```bash
python3 test_mcp.py
```

### Test Get Books Tool
```bash
python3 test_get_books_mcp.py
```

### Test Get Book By ID
```bash
python3 test_get_book.py
```

These scripts demonstrate:
- MCP protocol initialization
- Tool discovery
- Tool invocation
- Response parsing

## Running the Server

### Development Mode
```bash
dotnet run
```

### Production Build
```bash
dotnet build -c Release
dotnet bin/Release/net10.0/BookApiMcpServer.dll
```

### Publish for Distribution
```bash
dotnet publish -c Release -o ./publish
```

## Logging

The server uses Serilog for structured logging. Logs are written to the console with timestamps and log levels. The logging configuration can be adjusted in `appsettings.json`.

## Error Handling

- API connection errors are logged and returned as appropriate MCP error responses
- Invalid tool parameters result in validation errors
- Failed API calls return empty results (where applicable)

## Development

### Adding New Tools

To add a new MCP tool:

1. Add a static method to `BookTools.cs` (or create a new tool class)
2. Decorate with `[McpServerTool]` and `[Description("...")]` attributes
3. Tools are automatically discovered via `WithToolsFromAssembly()`

Example:
```csharp
[McpServerTool, Description("Search books by title")]
public static async Task<List<string>> SearchBooks(
    BookService bookService, 
    string query)
{
    // Implementation
}
```

### Project Properties

- **Target Framework**: .NET 10.0
- **Output Type**: Executable**
- **Implicit Usings**: Enabled
- **Nullable Reference Types**: Enabled

## License

[Add your license information here]

## Contributing

[Add contribution guidelines here]

