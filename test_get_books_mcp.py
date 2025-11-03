#!/usr/bin/env python3
"""Use MCP get_books tool to list all books"""
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

def read_json_response(process):
    """Read a JSON-RPC response, skipping log lines"""
    while True:
        line = process.stdout.readline()
        if not line:
            return None
        line = line.strip()
        if line and line.startswith('{'):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return None

print("Connecting to MCP server...", file=sys.stderr)

# Start the MCP server process
process = subprocess.Popen(
    ["dotnet", "bin/Release/net9.0/BookApiMcpServer.dll"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    text=True,
    bufsize=1
)

try:
    # Step 1: Initialize MCP connection
    print("Initializing MCP connection...", file=sys.stderr)
    init_req = send_request(1, "initialize", {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {"name": "cursor-client", "version": "1.0.0"}
    })
    process.stdin.write(init_req)
    process.stdin.flush()
    
    init_response = read_json_response(process)
    if not init_response or "result" not in init_response:
        print("ERROR: Failed to initialize MCP connection", file=sys.stderr)
        sys.exit(1)
    
    print("✓ MCP connection initialized", file=sys.stderr)
    
    # Step 2: Send initialized notification
    process.stdin.write('{"jsonrpc":"2.0","method":"initialized"}\n')
    process.stdin.flush()
    
    # Step 3: Call the get_books MCP tool
    print("\nCalling MCP tool: get_books", file=sys.stderr)
    tools_call = send_request(2, "tools/call", {
        "name": "get_books",
        "arguments": {}
    })
    process.stdin.write(tools_call)
    process.stdin.flush()
    
    # Step 4: Read the response
    response = read_json_response(process)
    
    if response:
        print(f"Response: {response}", file=sys.stderr)
    
    if response and "result" in response:
        result = response["result"]
        print(f"Result: {result}", file=sys.stderr)
        if "content" in result:
            content_text = result["content"][0]["text"]
            print(f"Content text: {content_text}", file=sys.stderr)
            books_list = json.loads(content_text)
            
            print(f"\n{'='*60}")
            print(f"Retrieved {len(books_list)} books using MCP get_books tool:")
            print(f"{'='*60}\n")
            
            for i, book_json_str in enumerate(books_list, 1):
                book = json.loads(book_json_str)
                title = book.get('Title') or book.get('title', 'N/A')
                author = book.get('Author') or book.get('author', 'N/A')
                isbn = book.get('Isbn') or book.get('isbn', 'N/A')
                pub_date = book.get('PublishedDate') or book.get('publishedDate', 'N/A')
                
                print(f"{i}. {title}")
                print(f"   Author: {author}")
                print(f"   ISBN: {isbn}")
                print(f"   Published: {pub_date[:10] if pub_date != 'N/A' else 'N/A'}")
                print()
            
            print(f"{'='*60}")
            print("✓ Successfully retrieved books using MCP tool only")
        else:
            print(f"ERROR: Unexpected response format: {result}", file=sys.stderr)
            sys.exit(1)
    else:
        print(f"ERROR: Failed to get books: {response}", file=sys.stderr)
        sys.exit(1)
        
finally:
    process.terminate()
    try:
        process.wait(timeout=2)
    except subprocess.TimeoutExpired:
        process.kill()

