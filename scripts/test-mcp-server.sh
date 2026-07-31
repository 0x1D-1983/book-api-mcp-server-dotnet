#!/usr/bin/env bash
# Curl-based MCP Streamable HTTP smoke tests for BookApi MCP Server.
# Exercises all MCP tools (mirrors BookApi REST CRUD + health).
# Prerequisites: docker compose stack is up (timescaledb + bookapi + bookapi-mcp-server).
# Usage: ./scripts/test-mcp-server.sh
# Optional: MCP_URL=http://localhost:5289 BOOKAPI_URL=http://localhost:5288 ./scripts/test-mcp-server.sh
set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:${PATH:-}"

MCP_URL="${MCP_URL:-http://localhost:5289}"
BOOKAPI_URL="${BOOKAPI_URL:-http://localhost:5288}"
MCP_ENDPOINT="${MCP_ENDPOINT:-${MCP_URL}/}"
TIMEOUT_SECS="${TIMEOUT_SECS:-90}"
DB_CONTAINER="${DB_CONTAINER:-timescaledb-book-api-mcp}"

pass=0
fail=0
rpc_id=0

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

assert_true() {
  local name="$1"
  if [[ "$2" == "1" || "$2" == "true" ]]; then
    green "PASS  ${name}"
    pass=$((pass + 1))
  else
    red "FAIL  ${name}"
    fail=$((fail + 1))
  fi
}

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    green "PASS  ${name}"
    pass=$((pass + 1))
  else
    red "FAIL  ${name} (missing '${needle}')"
    fail=$((fail + 1))
  fi
}

# POST JSON-RPC to MCP endpoint; write raw SSE body to $1
mcp_post() {
  local outfile="$1"
  local body="$2"
  curl -sS -X POST "${MCP_ENDPOINT}" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -d "${body}" \
    -o "${outfile}"
}

# Extract JSON-RPC object from SSE (first data: line) → stdout
sse_json() {
  local file="$1"
  python3 - "$file" <<'PY'
import json, re, sys
raw = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"(?m)^data:\s*(\{.*\})\s*$", raw)
if not m:
    # fallback: whole body is JSON
    raw = raw.strip()
    if raw.startswith("{"):
        print(raw)
        sys.exit(0)
    print("{}", end="")
    sys.exit(2)
print(m.group(1))
PY
}

# tools/call helper: prints content[0].text to stdout; writes full JSON-RPC to $3
call_tool() {
  local name="$1"
  local args_json="$2"
  local rpc_file="${3:-/tmp/mcp-call.json}"
  rpc_id=$((rpc_id + 1))
  local raw="/tmp/mcp-raw-${rpc_id}.txt"

  python3 - "$name" "$args_json" "$rpc_id" > /tmp/mcp-req.json <<'PY'
import json, sys
tool_name, args, rid = sys.argv[1], json.loads(sys.argv[2]), int(sys.argv[3])
json.dump(
    {"jsonrpc": "2.0", "id": rid, "method": "tools/call",
     "params": {"name": tool_name, "arguments": args}},
    sys.stdout,
)
PY
  mcp_post "${raw}" "$(cat /tmp/mcp-req.json)"
  sse_json "${raw}" > "${rpc_file}"
  python3 - "${rpc_file}" <<'PY'
import json, sys
obj = json.load(open(sys.argv[1], encoding="utf-8"))
if "error" in obj:
    print("", end="")
    raise SystemExit(0)
result = obj.get("result") or {}
content = result.get("content") or []
if content and isinstance(content, list):
    print(content[0].get("text", ""), end="")
else:
    print("", end="")
PY
}

# --- preflight ---
bold "Waiting for MCP health at ${MCP_URL}/health (timeout ${TIMEOUT_SECS}s)..."
deadline=$((SECONDS + TIMEOUT_SECS))
until curl -sf "${MCP_URL}/health" >/dev/null 2>&1; do
  if (( SECONDS >= deadline )); then
    red "FAIL  MCP server did not become healthy within ${TIMEOUT_SECS}s"
    echo "Hint: docker compose -f ../book-api-mcp-docker-compose-bundle/docker-compose.yml logs --tail=200 bookapi-mcp-server"
    exit 1
  fi
  sleep 2
done
green "PASS  MCP /health ready"
pass=$((pass + 1))

bold "Waiting for BookApi at ${BOOKAPI_URL}/health..."
deadline=$((SECONDS + TIMEOUT_SECS))
until curl -sf "${BOOKAPI_URL}/health" >/dev/null 2>&1; do
  if (( SECONDS >= deadline )); then
    red "FAIL  BookApi did not become healthy within ${TIMEOUT_SECS}s"
    exit 1
  fi
  sleep 2
done
green "PASS  BookApi /health ready"
pass=$((pass + 1))

if docker ps --format '{{.Names}}' | grep -qx "${DB_CONTAINER}"; then
  docker exec "${DB_CONTAINER}" psql -U admin -d booksdb -v ON_ERROR_STOP=1 -c "
    CREATE TABLE IF NOT EXISTS books (
      id SERIAL PRIMARY KEY,
      title VARCHAR(500) NOT NULL,
      author VARCHAR(300) NOT NULL,
      isbn VARCHAR(20),
      published_date TIMESTAMP NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  " >/dev/null
fi

# --- initialize + tools/list ---
bold "MCP initialize"
rpc_id=$((rpc_id + 1))
mcp_post /tmp/mcp-init.txt "$(cat <<EOF
{"jsonrpc":"2.0","id":${rpc_id},"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-mcp-server","version":"1.0.0"}}}
EOF
)"
sse_json /tmp/mcp-init.txt > /tmp/mcp-init.json
assert_contains "initialize result" "$(cat /tmp/mcp-init.json)" "protocolVersion"
assert_contains "initialize serverInfo" "$(cat /tmp/mcp-init.json)" "BookApiMcpServer"

mcp_post /tmp/mcp-notif.txt '{"jsonrpc":"2.0","method":"notifications/initialized"}' || true

bold "MCP tools/list"
rpc_id=$((rpc_id + 1))
mcp_post /tmp/mcp-tools-raw.txt "$(cat <<EOF
{"jsonrpc":"2.0","id":${rpc_id},"method":"tools/list"}
EOF
)"
sse_json /tmp/mcp-tools-raw.txt > /tmp/mcp-tools.json
tools_csv="$(python3 - <<'PY'
import json
obj=json.load(open("/tmp/mcp-tools.json"))
names=sorted(t["name"] for t in obj.get("result",{}).get("tools",[]))
print(",".join(names))
PY
)"
assert_contains "tools/list has get_health" "$tools_csv" "get_health"
assert_contains "tools/list has get_books" "$tools_csv" "get_books"
assert_contains "tools/list has get_book_by_id" "$tools_csv" "get_book_by_id"
assert_contains "tools/list has create_book" "$tools_csv" "create_book"
assert_contains "tools/list has update_book" "$tools_csv" "update_book"
assert_contains "tools/list has delete_book" "$tools_csv" "delete_book"

# --- get_health ---
bold "tools/call get_health"
health_text="$(call_tool get_health '{}' /tmp/mcp-health.json)"
assert_contains "get_health text" "$health_text" "Healthy"

# --- get_books ---
bold "tools/call get_books"
books_text="$(call_tool get_books '{}' /tmp/mcp-books.json)"
python3 - "$books_text" <<'PY' >/tmp/mcp-books-ok.txt
import json,sys
raw=sys.argv[1]
try:
    data=json.loads(raw) if raw else []
    ok = isinstance(data, list)
except Exception:
    ok=False
print("1" if ok else "0")
PY
assert_true "get_books returns JSON array" "$(cat /tmp/mcp-books-ok.txt)"

# --- create_book ---
bold "tools/call create_book"
unique_isbn="978-MCP-$(date +%s)"
create_args="$(python3 - <<PY
import json
print(json.dumps({"book":{
  "title":"MCP Agent Loop Test Book",
  "author":"MCP Test Author",
  "isbn":"${unique_isbn}",
  "publishedDate":"2024-06-01T00:00:00Z"
}}))
PY
)"
create_text="$(call_tool create_book "${create_args}" /tmp/mcp-create.json)"
printf '%s' "$create_text" > /tmp/mcp-create-text.txt
assert_contains "create_book title" "$create_text" "MCP Agent Loop Test Book"
assert_contains "create_book isbn" "$create_text" "${unique_isbn}"

book_id="$(python3 - <<'PY'
import json
book=json.load(open("/tmp/mcp-create-text.txt", encoding="utf-8"))
print(book.get("Id") or book.get("id") or "")
PY
)"
if [[ -z "${book_id}" ]]; then
  red "FAIL  could not parse created book id from: ${create_text}"
  fail=$((fail + 1))
  bold "Results: ${pass} passed, ${fail} failed"
  exit 1
fi
green "PASS  parsed created id=${book_id}"
pass=$((pass + 1))

# --- get_book_by_id ---
bold "tools/call get_book_by_id"
get_text="$(call_tool get_book_by_id "{\"id\":${book_id}}" /tmp/mcp-get.json)"
assert_contains "get_book_by_id title" "$get_text" "MCP Agent Loop Test Book"

# --- get missing ---
bold "tools/call get_book_by_id missing"
missing_text="$(call_tool get_book_by_id '{"id":999999999}' /tmp/mcp-missing.json)"
if [[ -z "${missing_text}" ]]; then
  green "PASS  get_book_by_id missing → empty"
  pass=$((pass + 1))
else
  red "FAIL  get_book_by_id missing expected empty, got: ${missing_text}"
  fail=$((fail + 1))
fi

# --- update_book ---
bold "tools/call update_book"
update_args="$(python3 - <<PY
import json
print(json.dumps({"book":{
  "id": ${book_id},
  "title":"Updated MCP Agent Loop Book",
  "author":"Updated MCP Author",
  "isbn":"${unique_isbn}",
  "publishedDate":"2024-07-01T00:00:00Z"
}}))
PY
)"
update_text="$(call_tool update_book "${update_args}" /tmp/mcp-update.json)"
assert_contains "update_book title" "$update_text" "Updated MCP Agent Loop Book"

verify_text="$(call_tool get_book_by_id "{\"id\":${book_id}}" /tmp/mcp-verify.json)"
assert_contains "get after update" "$verify_text" "Updated MCP Agent Loop Book"

# --- delete_book ---
bold "tools/call delete_book"
delete_rpc="/tmp/mcp-delete.json"
call_tool delete_book "{\"id\":${book_id}}" "${delete_rpc}" >/tmp/mcp-delete-text.txt
python3 - <<'PY' >/tmp/mcp-delete-ok.txt
import json
obj=json.load(open("/tmp/mcp-delete.json"))
ok = "error" not in obj and "result" in obj
# isError on tool result also counts as failure
result=obj.get("result") or {}
if result.get("isError"):
    ok=False
print("1" if ok else "0")
PY
assert_true "delete_book succeeds" "$(cat /tmp/mcp-delete-ok.txt)"

gone_text="$(call_tool get_book_by_id "{\"id\":${book_id}}" /tmp/mcp-gone.json)"
if [[ -z "${gone_text}" ]]; then
  green "PASS  get after delete → empty"
  pass=$((pass + 1))
else
  red "FAIL  get after delete expected empty, got: ${gone_text}"
  fail=$((fail + 1))
fi

# --- summary ---
echo
bold "Results: ${pass} passed, ${fail} failed"
if (( fail > 0 )); then
  exit 1
fi
echo "✅ test-mcp-server.sh passed"
