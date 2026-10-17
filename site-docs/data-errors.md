# Pass data and recover from errors

## JSON to Lua and back

JSON `args` become Lua varargs (`...`). JSON null maps to the singleton
`require('lua_repl_mcp').null`, including nested values. Lua nil return slots
are preserved as JSON null; zero returns produce an empty `values` list.
There is no implicit return or automatic print capture.

Dense positive integer-keyed tables become arrays. String-keyed tables become
objects; an empty table becomes an object, including an empty input array returned
unchanged. Sparse, mixed-key or cyclic tables are not serializable. Raw entries
are used rather than user metamethods. Functions, userdata and threads are not
JSON results. Strings must be valid UTF-8.

Integers must be in the JSON-safe range -9007199254740991 to 9007199254740991.
Out-of-range integer tokens are rejected even if floating conversion would round
them. Finite nonintegral numbers use binary64 rounding; NaN/infinity and overflow
are rejected. Bounds apply to nested data and return tuples too.

## Explicit null example

Call `session_execute` with these arguments (or use code/args on `repl_execute`):

```json
{"code":"local x = ...; return x, nil, {label = 'ok'}","args":[null],"wait_timeout_ms":1000}
```

On completion expect `[null, null, {"label":"ok"}]`. Save the result once.

## Understand the failure layer

Malformed JSON/JSON-RPC and unknown protocol methods are protocol errors.
Tool operation errors are in the tool result (`isError` and `structuredContent`),
with code, stage and execution state. Execution syntax/runtime/conversion failures
are not proof that no effects happened. Check status and `session_usable` before
reading values or deciding to retry. Error diagnostic wording is not fixed.

| Problem | What to do |
| --- | --- |
| Syntax error | Correct the complete chunk; inspect usable state |
| Runtime error after mutation | Read state before retrying the mutation |
| Unsupported/cyclic/sparse return | Return a JSON-compatible summary instead |
| Serialization/size/depth failure | Entire return payload is rejected; reduce data, do not assume rollback |
| `session_busy` | Wait on existing work or use another session |
| `result_unavailable` | Use the previously saved payload; do not expect a second consumption |
| Unknown/unusable session | Allocate new state after inspecting cause |
| Client timeout/lost response | Inspect connection/session state; never blindly replay effects |

Conversion errors include RFC 6901 JSON Pointers when applicable (`~0` escapes
`~`, `~1` escapes `/`). Diagnostics can be truncated with flags and a loss notice.
For example `counter = 9; return function() end` fails conversion atomically,
but `return counter` in the usable session still yields `[9]`.

Use [schemas](docs/schemas/api.json) for exact errors/fields and
[wire examples](docs/MCP_EXAMPLES.md) for completed, pending and error responses.
