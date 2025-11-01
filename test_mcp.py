#!/usr/bin/env python3
"""Test script for MCP server connection"""
import json
import subprocess
import sys
import time

def send_request(request_id, method, params=None):
    """Send a JSON-RPC request"""
    message = {
        "jsonrpc": "2.0",
        "id": request_id,
        "method": method
    }
    if params:
        message["params"] = params
    
    json_message = json.dumps(message)
    print(f"Sending: {json_message}", file=sys.stderr)
    return json_message + "\n"

def read_response(process, timeout=5):
    """Read a response from the process"""
    try:
        while True:
            line = process.stdout.readline()
            if not line:
                return None
            line = line.strip()
            if not line:
                continue
            # Skip log lines (they don't start with {)
            if line.startswith('[') or not line.startswith('{'):
                print(f"Log line (skipping): {line}", file=sys.stderr)
                continue
            print(f"Received: {line}", file=sys.stderr)
            return json.loads(line)
    except json.JSONDecodeError as e:
        print(f"JSON decode error: {e}, line was: {line}", file=sys.stderr)
        return None
    return None

def test_mcp_server():
    """Test the MCP server connection"""
    print("Starting MCP server test...", file=sys.stderr)
    
    # Start the MCP server process
    process = subprocess.Popen(
        ["dotnet", "run", "--project", "BookApiMcpServer.csproj", "--no-build"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1
    )
    
    try:
        # Send initialize request
        init_request = send_request(1, "initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {
                "name": "test-client",
                "version": "1.0.0"
            }
        })
        process.stdin.write(init_request)
        process.stdin.flush()
        
        # Read initialize response
        init_response = read_response(process)
        if init_response and "result" in init_response:
            print("\n✓ Initialize successful", file=sys.stderr)
            print(f"  Server capabilities: {init_response.get('result', {}).get('capabilities', {})}", file=sys.stderr)
        else:
            print("\n✗ Initialize failed", file=sys.stderr)
            return False
        
        # Send initialized notification (notifications don't have id)
        initialized_notification = json.dumps({
            "jsonrpc": "2.0",
            "method": "initialized"
        })
        process.stdin.write(initialized_notification + "\n")
        process.stdin.flush()
        
        time.sleep(0.5)  # Give server time to process
        
        # List tools
        tools_request = send_request(2, "tools/list")
        process.stdin.write(tools_request)
        process.stdin.flush()
        
        # Read tools list response
        tools_response = read_response(process)
        if tools_response and "result" in tools_response:
            tools = tools_response["result"].get("tools", [])
            print(f"\n✓ Found {len(tools)} tools:", file=sys.stderr)
            for tool in tools:
                print(f"  - {tool.get('name')}: {tool.get('description', 'No description')}", file=sys.stderr)
            
            # Check if get_books tool exists (MCP converts to snake_case)
            getbooks_tool = next((t for t in tools if t.get("name") in ["GetBooks", "get_books"]), None)
            if getbooks_tool:
                tool_name = getbooks_tool.get("name")
                print(f"\n✓ GetBooks tool found (name: {tool_name}):", file=sys.stderr)
                print(f"  Description: {getbooks_tool.get('description')}", file=sys.stderr)
                
                # Try calling GetBooks
                print("\nTesting GetBooks tool call...", file=sys.stderr)
                call_request = send_request(3, "tools/call", {
                    "name": tool_name,
                    "arguments": {}
                })
                process.stdin.write(call_request)
                process.stdin.flush()
                
                call_response = read_response(process, timeout=10)
                if call_response and "result" in call_response:
                    print("\n✓ GetBooks call successful!", file=sys.stderr)
                    result = call_response["result"]
                    if "content" in result:
                        content = result["content"]
                        if isinstance(content, list) and len(content) > 0:
                            books_json = content[0].get("text", "[]")
                            try:
                                books_data = json.loads(books_json)
                                print(f"\nRetrieved {len(books_data)} books:", file=sys.stderr)
                                for book_str in books_data:
                                    book_obj = json.loads(book_str) if isinstance(book_str, str) else book_str
                                    # Handle both PascalCase and camelCase property names
                                    title = book_obj.get('Title') or book_obj.get('title', 'Unknown')
                                    author = book_obj.get('Author') or book_obj.get('author', 'Unknown')
                                    print(f"  - {title} by {author}", file=sys.stderr)
                            except json.JSONDecodeError as e:
                                print(f"\nBooks data parsing error: {e}", file=sys.stderr)
                                print(f"Raw data: {books_json[:200]}...", file=sys.stderr)
                    elif "isError" in result:
                        print(f"\n✗ GetBooks returned error: {result.get('error', {})}", file=sys.stderr)
                        return False
                    return True
                elif call_response and "error" in call_response:
                    print(f"\n✗ GetBooks call failed with error: {call_response.get('error', {})}", file=sys.stderr)
                    return False
                else:
                    print(f"\n✗ GetBooks call failed: {call_response}", file=sys.stderr)
                    return False
            else:
                print("\n✗ GetBooks tool not found in tools list", file=sys.stderr)
                return False
        else:
            print(f"\n✗ Failed to list tools: {tools_response}", file=sys.stderr)
            return False
            
    except Exception as e:
        print(f"\n✗ Error during test: {e}", file=sys.stderr)
        return False
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
        stderr_output = process.stderr.read()
        if stderr_output:
            print(f"\nServer stderr:\n{stderr_output}", file=sys.stderr)

if __name__ == "__main__":
    success = test_mcp_server()
    sys.exit(0 if success else 1)

