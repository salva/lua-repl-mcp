# MCP usage examples

These examples illustrate the public MCP protocol. JSON is pretty-printed
for readability; actual stdio/control frames occupy one line. Session IDs are
illustrative. Error diagnostic wording is not fixed; codes and fields are.

## Initialize

Client:

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"example-client","version":"1.0"}}}
```

Server:

```json
{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-11-25","capabilities":{"tools":{}},"serverInfo":{"name":"lua-repl-mcp","version":"0.1.0"},"instructions":"Lua globals persist per session. Use explicit return for values. Results are consumed when returned. Request cancellation kills the associated managed session; wait-timeout expiry does not."}}
```

Client:

```json
{"jsonrpc":"2.0","method":"notifications/initialized"}
```

The client can now call `tools/list` to obtain names, descriptions and schemas.
The version string is illustrative, not a release commitment. A direct handler
advertises `repl_execute` and `repl_close`, with instructions appropriate to its
host rather than managed-session lifecycle instructions.

### Reproducible discovery and schema check

From the repository root, with Python 3 and `jsonschema==4.19.2` installed:

```sh
python3 docs/check_contracts.py
```

This expands all fourteen input/output schemas without external references,
validates manager and direct-handler `tools/list` results against the official
MCP 2025-11-25 `Tool` and `ListToolsResult` schemas, checks the JSON examples
below, and runs positive/negative regression fixtures. The official schema is
downloaded from a pinned upstream commit and SHA-256 checked. For offline use,
pass `--mcp-schema PATH` with that exact downloaded file. Use `--discovery` to
print the two validated discovery result objects. This is a documentation
contract check, not a live-server test. Defaults remain runtime responsibilities.

## Allocate and execute synchronously

```json
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"session_create","arguments":{"cwd":"/example/project","stdout_path":"run.stdout","stderr_path":"run.stderr"}}}
```

```json
{"jsonrpc":"2.0","id":2,"result":{"isError":false,"structuredContent":{"session_id":"s1","session_status":"idle"},"content":[{"type":"text","text":"{\"session_id\":\"s1\",\"session_status\":\"idle\"}"}]}}
```

The files must not already exist. Input defaults to `/dev/null`.

```json
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"session_execute","arguments":{"session_id":"s1","code":"local n = ...; counter = (counter or 0) + n; return counter, nil","args":[2],"wait_timeout_ms":null}}}
```

```json
{"jsonrpc":"2.0","id":3,"result":{"isError":false,"structuredContent":{"session_id":"s1","session_status":"idle","session_usable":true,"status":"completed","values":[2,null]},"content":[{"type":"text","text":"{\"session_id\":\"s1\",\"session_status\":\"idle\",\"session_usable\":true,\"status\":\"completed\",\"values\":[2,null]}"}]}}
```

The result has been consumed; `counter` remains 2. A later `session_wait` fails
with `result_unavailable`, not with a repeated copy of `[2,null]`.

## Implicit creation and asynchronous wait

```json
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"session_execute","arguments":{"session_id":null,"create_options":{"cwd":"/example/project"},"code":"answer = 42; return answer","wait_timeout_ms":0,"execution_timeout_ms":600000}}}
```

```json
{"jsonrpc":"2.0","id":4,"result":{"isError":false,"structuredContent":{"session_id":"s2","session_status":"running","session_usable":true,"status":"running"},"content":[{"type":"text","text":"{\"session_id\":\"s2\",\"session_status\":\"running\",\"session_usable\":true,\"status\":\"running\"}"}]}}
```

The pending response records acceptance; it is not a promise that the worker
will still be running when the client receives it. Use the returned session ID:

```json
{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"session_wait","arguments":{"session_id":"s2","wait_timeout_ms":1000}}}
```

```json
{"jsonrpc":"2.0","id":5,"result":{"isError":false,"structuredContent":{"session_id":"s2","session_status":"idle","session_usable":true,"status":"completed","values":[42]},"content":[{"type":"text","text":"{\"session_id\":\"s2\",\"session_status\":\"idle\",\"session_usable\":true,\"status\":\"completed\",\"values\":[42]}"}]}}
```

If still running after 1000 ms, the reply instead has pending status and no
values; the client may wait again. It must not resubmit the code to poll it.
Omitted wait time is 600000 ms. A hard deadline is separate and kills the session.

## Operation error versus execution outcome

For brevity, the following blocks show `structuredContent`; wrap each in the
same MCP result form above with a text copy and the stated `isError` value.

A second wait after consumption has `isError: true` even though execution succeeded:

<!-- schema: session_wait_output -->
```json
{"session_id":"s2","session_status":"idle","session_usable":true,"status":"completed","error":{"code":"result_unavailable","message":"The result was already returned and consumed.","stage":"validation","execution_state":"completed"}}
```

A second execution while busy has `isError: true`; the new code did not run:

<!-- schema: session_execute_output -->
```json
{"session_id":"s2","session_status":"running","session_usable":true,"status":"running","error":{"code":"session_busy","message":"Wait for this session or use another session.","stage":"validation","execution_state":"not_started"}}
```

Returning a function after updating state fails serialization (`isError: true`):

```lua
counter = (counter or 0) + 1
return function() end
```

<!-- schema: session_execute_output -->
```json
{"session_id":"s1","session_status":"idle","session_usable":true,"status":"failed","error":{"code":"result_serialization_error","message":"Execution completed and its effects remain. A function cannot be returned as JSON. Do not rerun automatically.","stage":"serialization","execution_state":"completed","path":"/values/0"}}
```

## Kill and cancellation

```json
{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"session_kill","arguments":{"session_id":"s2"}}}
```

Successful structured content (`isError: false`):

<!-- schema: session_kill_output -->
```json
{"session_id":"s2","status":"killed","session_usable":false,"process_exit_confirmed":true}
```

Exceptional best-effort cleanup is also successful:

<!-- schema: session_kill_output -->
```json
{"session_id":"s2","status":"killed","session_usable":false,"process_exit_confirmed":false,"notice":"The managed session was removed, but OS process exit was not confirmed; the process may remain alive."}
```

Later use of the removed ID fails with `unknown_session`. A fatal async failure
can likewise leave only an unknown session; this does not imply its code never ran.

To cancel an outstanding wait with JSON-RPC ID 7:

```json
{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":7,"reason":"Stop this execution"}}
```

This kills its managed session. The notification has no response and the cancelled
request need not receive one. Cancelling an already-answered async request does
nothing; use `session_kill`. A normal wait deadline is not cancellation.

## List

`session_list` with `{}` returns (`isError: false`):

<!-- schema: session_list_output -->
```json
{"sessions":[{"session_id":"s1","session_status":"idle","execution_status":"failed","result_available":false,"cwd":"/example/project"}]}
```

Consumed results and closed sessions are not history. Empty managers return
`{"sessions":[]}`.

## Managed custom-host creation

Use session tools for a prepared foreground executable embedding Lua, not a
public `repl_execute` handler. See [host integration](../site-docs/custom-host.md)
for FD3/bootstrap/module requirements and destructive lifecycle limitations.
Replace the illustrative executable/directory with your installed host:

```json
{"jsonrpc":"2.0","id":20,"method":"tools/call","params":{"name":"session_create","arguments":{"command":["/opt/example/bin/lua-host","--managed-session","--label",""],"cwd":"/data/trial","stdout_path":"host-output.log","stderr_path":"host-error.log"}}}
```

Expect the normal idle session-create result on readiness. Literal argv has no
shell expansion; empty later arguments are retained. Output files must not exist.
For implicit creation:

```json
{"jsonrpc":"2.0","id":21,"method":"tools/call","params":{"name":"session_execute","arguments":{"create_options":{"command":["/opt/example/bin/lua-host","--managed-session"]},"code":"total = host_add(20, 22); return total","wait_timeout_ms":1000}}}
```

If your host implements `host_add`, completion returns `[42]`; pending requires
`session_wait` with the returned ID. The example API is not provided by this
package. Never replay to poll. Same-state persistence, single-consumption and
serialization-after-effects semantics are unchanged. Active cancellation,
hard deadline, kill and manager loss destroy the owned application host; none
is an application-level non-destructive Stop or rollback guarantee.

## Direct embedded handler

```json
{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"repl_execute","arguments":{"code":"local x = ...; host_value = x; return host_value","args":[7]}}}
```

Successful structured content:

<!-- schema: repl_execute_output -->
```json
{"status":"completed","values":[7]}
```
There is no session ID or asynchronous mode. No output is captured automatically.

```json
{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"repl_close","arguments":{}}}
```

```json
{"jsonrpc":"2.0","id":9,"result":{"isError":false,"structuredContent":{"status":"closing"},"content":[{"type":"text","text":"{\"status\":\"closing\"}"}]}}
```

After flushing this acknowledgement, the handler returns to its parent with
close reason, request ID 9, acknowledgement status, and any buffered trailing
messages/partial bytes. It does not close transport handles or reset Lua globals.

## Explicit client-controlled capture and null

Clients may submit Lua that accumulates messages as data without replacing host
output functions:

```lua
local messages = {}
local function emit(text) messages[#messages + 1] = text end
emit("started")
emit("finished")
return messages
```

For null input: `local value = ...; return value == require('lua_repl_mcp').null`
with `args: [null]` returns `[true]`. Empty Lua tables return JSON objects;
nonempty consecutive integer-keyed tables return arrays. Unsupported values
fail the entire result; they are never replaced by descriptive strings.
