#!/usr/bin/env python3
"""Quick test for get_book_by_id tool"""
import json
import subprocess
import sys

def send_request(request_id, method, params=None):
    """Send a JSON-RPC request"""
    message = {
        "jsonrpc": "2.0",
        "id": request_id,
        "method": method
    }
    if params:
        message["params"] = params
    return json.dumps(message) + "\n"

def read_json_line(process):
    """Read a JSON-RPC response line, skipping logs"""
    while True:
        line = process.stdout.readline()
        if not line:
            return None
        line = line.strip()
        if line.startswith('{'):
            return json.loads(line)
    return None

# Start the MCP server
process = subprocess.Popen(
    ["dotnet", "run", "--project", "BookApiMcpServer.csproj", "--no-build"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    text=True,
    bufsize=1
)

try:
    # Initialize
    init_req = send_request(1, "initialize", {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {"name": "test", "version": "1.0"}
    })
    process.stdin.write(init_req)
    process.stdin.flush()
    
    read_json_line(process)  # Skip init response
    
    # Send initialized notification
    process.stdin.write('{"jsonrpc":"2.0","method":"initialized"}\n')
    process.stdin.flush()
    
    # Call get_book_by_id with id=5
    call_req = send_request(2, "tools/call", {
        "name": "get_book_by_id",
        "arguments": {"id": 5}
    })
    process.stdin.write(call_req)
    process.stdin.flush()
    
    # Read response
    response = read_json_line(process)
    if response and "result" in response:
        result = response["result"]
        if "content" in result:
            content = result["content"][0]["text"]
            book = json.loads(content)
            # Handle PascalCase properties
            book_data = json.loads(book) if isinstance(book, str) else book
            print(f"Book ID 5:")
            print(f"  Title: {book_data.get('Title') or book_data.get('title', 'N/A')}")
            print(f"  Author: {book_data.get('Author') or book_data.get('author', 'N/A')}")
            print(f"  ISBN: {book_data.get('Isbn') or book_data.get('isbn', 'N/A')}")
            print(f"  Published: {book_data.get('PublishedDate') or book_data.get('publishedDate', 'N/A')}")
        else:
            print(f"Error: {result}")
    else:
        print(f"Failed: {response}")
finally:
    process.terminate()
    process.wait(timeout=2)

