# BookApi MCP Server agentic code + test loop

Implement the user task against this **BookApi MCP Server** (.NET Model Context Protocol server), then verify with the docker-compose stack and curl-based MCP tool tests. Keep iterating until the loop is green.

Any text after `/task` is the work item (bug fix, feature, refactor, etc.). If none is provided, ask what to implement before coding.

## Product spec (source of truth)

BookApi MCP Server is an ASP.NET Core MCP host that bridges MCP clients to the BookApi REST backend. It exposes book CRUD (and health) as MCP tools over **Streamable HTTP** on port **5289**. Stay on MCP tools + BookService HTTP client work — do not rewrite the BookApi REST service here unless the task explicitly requires a cross-repo fix.

### Book model (tool payloads)

| Field           | Type     | Notes                                      |
|-----------------|----------|--------------------------------------------|
| `id` / `Id`     | int      | DB-generated; required on update payload   |
| `title`         | string   | required                                   |
| `author`        | string   | required                                   |
| `isbn`          | string   | optional                                   |
| `publishedDate` | DateTime | required (UTC / ISO-8601)                  |
| `createdAt`     | DateTime | set by BookApi on create                   |

Tool **arguments** use camelCase schemas. Serialized book **results** from tools currently use System.Text.Json defaults (often PascalCase) — assert either casing.

### MCP transport

| Item | Value |
|------|--------|
| Base URL (compose) | `http://localhost:5289` |
| Health HTTP | `GET /health` → `200` `{"status":"ok"}` |
| MCP endpoint | `POST /` (Streamable HTTP; `MapMcp()` at root) |
| Headers | `Content-Type: application/json`, `Accept: application/json, text/event-stream` |
| Response | `text/event-stream` with `event: message` + `data: <json-rpc>` |

JSON-RPC methods used by the loop: `initialize`, `notifications/initialized`, `tools/list`, `tools/call`.

### MCP tools (mirror BookApi REST)

| Tool              | Args | Mirrors | Success shape |
|-------------------|------|---------|---------------|
| `get_health`      | none | `/health` | text `"Healthy"` |
| `get_books`       | none | `GET /books` | JSON array of book JSON strings |
| `get_book_by_id`  | `id` (int) | `GET /books/{id}` | book JSON string, or `""` if missing |
| `create_book`     | `book` (object) | `POST /books` | created book JSON string |
| `update_book`     | `book` (object, incl. `id`) | `PUT /books/{id}` | updated book JSON string |
| `delete_book`     | `id` (int) | `DELETE /books/{id}` | often `""` on success (API returns 204) |

`create_book` / `update_book` argument example:

```json
{
  "book": {
    "title": "Book Title",
    "author": "Author Name",
    "isbn": "978-1234567890",
    "publishedDate": "2023-01-01T00:00:00Z"
  }
}
```

### Layout to respect

- `Tools/BookTools.cs`, `Tools/HealthTools.cs` — `[McpServerTool]` / `[McpServerToolType]`
- `Services/BookService.cs` — HttpClient calls to BookApi
- `Models/Book.cs`, `Models/BookApiConfig.cs`
- `Program.cs` — `AddMcpServer().WithHttpTransport().WithToolsFromAssembly()`, `MapMcp()`, listen `http://0.0.0.0:5289`
- `appsettings.json` — `BookApi:BaseUrl`
- Async all the way; structured logging; no `Console.WriteLine` in service code

## Paths

- **MCP repo:** `/Users/oxid/code/book-api-mcp-server-dotnet`
- **BookApi repo (dependency):** `/Users/oxid/code/book-api`
- **Compose file:** `/Users/oxid/code/book-api-mcp-docker-compose-bundle/docker-compose.yml`
- **MCP test script:** `/Users/oxid/code/book-api-mcp-server-dotnet/scripts/test-mcp-server.sh`

Compose builds `bookapi-mcp-server` from `../book-api-mcp-server-dotnet` (host **5289**) and `bookapi` from `../book-api` (host **5288**). Env: `BookApi__BaseUrl=http://bookapi:5288`. DB: `booksdb` / `admin` / `admin123`.

## Verification loop (mandatory after every change)

Work from `/Users/oxid/code/book-api-mcp-server-dotnet`. Repeat until all steps succeed:

1. **Build** (must be warning-free):

   ```bash
   dotnet build
   ```

2. **Bring up stack** (rebuild so containers pick up code changes; MCP needs BookApi + DB):

   ```bash
   docker compose -f /Users/oxid/code/book-api-mcp-docker-compose-bundle/docker-compose.yml up -d --build timescaledb bookapi bookapi-mcp-server
   ```

3. **Run MCP tool tests** (curl Streamable HTTP only; do not replace with unit-test projects for this loop):

   ```bash
   ./scripts/test-mcp-server.sh
   ```

4. On failure:
   - Read `docker compose -f ... logs --tail=200 bookapi-mcp-server` (and `bookapi` / `timescaledb` if needed)
   - Fix the **root cause** in the MCP server (or BookApi only if the failure is clearly an API contract break your task depends on)
   - Prefer fixing production code over weakening `test-mcp-server.sh`
   - Go back to step 1

5. On success:

   ```bash
   docker compose -f /Users/oxid/code/book-api-mcp-docker-compose-bundle/docker-compose.yml down
   ```

Do **not** declare done on container “Up” alone — MCP `GET /health`, BookApi readiness, and `./scripts/test-mcp-server.sh` must pass.

## Constraints

- Scope changes to what the task needs; no drive-by refactors or unrelated docs
- Do not commit or push unless the user explicitly asks
- Claude Desktop / Cursor `mcp.json` wiring is out of scope unless the task includes it
- Auth (`ConfigureMcpSecurity` / JWT) stays off unless the task turns it on — tests assume open `MapMcp()`

## Report back

When finished, briefly state: what changed, that `dotnet build` + `./scripts/test-mcp-server.sh` passed, and any residual risks.
