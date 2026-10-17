## U10 trial results

Used **44 tool calls**, exclusively `mcp_server_control`, `mcp_tools`, and `mcp_tool_call` on `lua`. No project execution, source changes, secret inspection, or shell tool use.

Discovered all five exact tool schemas and the binding ID before execution. The actual timeout parameters are **`wait_timeout_ms`** and **`execution_timeout_ms`**.

### 1. Persistent state, JSON arguments, and isolation — passed
- Explicitly created `session-1-1`.
- Defined `n=40` and `add(x)`. The no-return chunk completed with `values: []`.
- The next execution asserted the calculation and JSON argument fields, then returned:
  ```json
  [42, null, {"count":3,"tag":"json"}]
  ```
  This contains exactly three values, preserving the middle Lua `nil` as JSON `null`.
- Explicitly created `session-1-2`; assertions confirmed both `n` and `add` were absent. Returned `[true,true]`.

### 2. Implicit session and synchronous return — passed
Omitting `session_id` created `session-1-3` and returned:
```json
[{"kind":"implicit","ok":true}]
```
All value-producing chunks used explicit `return`; no implicit expression return was assumed.

### 3. Async execution and result consumption — partially demonstrated
- `sleep 1; return 73` with `wait_timeout_ms:0` returned `status:"running"`: pending, not terminal.
- Listing subsequently showed completion with `result_available:true`.
- The finite 1 ms wait returned terminal `[73]`, demonstrating that listing had not consumed it.
- The following unbounded wait and another poll both returned **`result_unavailable`**, with the session still usable.
- A subsequent execution returned `[74]`.

**Timing limitation:** completion occurred before the finite wait. Thus, the finite wait—not the unbounded wait—consumed the terminal result.

### 4. Recoverable errors and exactly-once side effects — passed
All three errors left the session idle and usable:
- **`lua_syntax_error`**, `execution_state:"not_started"`: the preceding textual side effect did not execute.
- **`lua_runtime_error`**, `execution_state:"started"`: the counter increment survived.
- **`result_serialization_error`**, `execution_state:"completed"`, path `/values/0`: returning a function failed serialization; side effects were not rolled back.

A later valid execution asserted the state and returned:
```json
[null, 1, 1, 42]
```
This verified no syntax-error side effect, exactly one runtime-error increment, exactly one serialization-error increment, and preserved original globals.

### 5. Finite waiting and kill — partial; no retained fatal result
- The first async `sleep 2` returned pending, but the subsequent finite wait already returned terminal `[75]`; wait expiry was not observed there.
- An unrelated session returned `[42]`.
- A second `sleep 2` execution with a finite 1 ms execute-wait returned pending, demonstrating that this wait deadline left work running at reply time.
- Killing that session returned **`killed`**, `session_usable:false`, and `process_exit_confirmed:true`.
- The attempted fatal-result retrieval returned **`unknown_session`**, not a retained fatal result.
- Repeated kill also returned **`unknown_session`**, consistent with the discovered no-history contract.

**Uncertainty:** separate-call timing does not prove the Lua chunk remained active at the instant kill was processed.

### 6. Independent hard execution timeout — demonstrated, with a retrieval limitation
- An implicit execution with `execution_timeout_ms:100` and zero wait returned pending as `session-1-4`.
- Its later unbounded wait returned **`unknown_session`**; no timeout result was retrievable through that path.
- A separate bounded probe using the same hard timeout and an unbounded execute-wait returned **`execution_timeout`**, `execution_state:"started"`, terminated/unusable session, and confirmed process exit.
- The unrelated session then returned `[42]`.

### 7. Independent client invocation deadline — observed broader disruption
Executed `sleep 65` with both timeout parameters `null`, **once only; not retried**.

- The invocation failed with **“timed out after 30000ms.”**
- The required subsequent list failed with **“MCP server 'lua' is not running.”**
- Therefore, continued usability of the original unrelated session could **not** be demonstrated.
- Restarted `lua`, rediscovered fresh bindings, and observed an empty session list.
- A new session returned `[42]`, proving usability **after restart**, not survival across the deadline.

This was a **client/MCP invocation timeout**, not an observed Lua `execution_timeout`. No session ID was returned for the deadline invocation. The tool results do not establish its exact cancellation timing or OS-process disposition.

### Cleanup
After restart, the only listed session was explicitly killed with confirmed process exit. The final list was empty, and `lua` was successfully stopped.

**Overall:** persistence, isolation, JSON/null handling, recoverable errors, result consumption, and hard timeout behavior were demonstrated. The requested retained fatal-result retrieval and pre-existing-session survival after the client deadline were **not** demonstrated; observed results were `unknown_session` and server unavailability, respectively.

Completed in **18 calls**, using only Lua MCP control, discovery, and invocation tools. No side-effecting execution was retried.

### 1. Finite wait expiry, terminal retrieval, consumption
Implicit execution of `sleep 1; return 81`, with `wait_timeout_ms:1` and no hard timeout:
- Returned **pending**: `status:"running"`, session `session-1-1`, usable.
- Unbounded wait returned **terminal success**: `status:"completed"`, `values:[81]`, session idle and usable.
- Another wait returned the expected **`result_unavailable`** validation error, with `execution_state:"completed"`. This confirms the terminal retrieval consumed the result; it did not destroy the session.

### 2. Hard deadline captured in the execute request
Implicit execution of `sleep 2; return 82`, with `execution_timeout_ms:100` and unbounded wait:
- The execute request itself returned **`execution_timeout`**.
- Reported `execution_state:"started"`, `status:"failed"`, session `session-1-2` terminated and unusable, and **`process_exit_confirmed:true`**.
- No `82` result was returned. This was a hard Lua execution deadline, not a client invocation timeout.

### 3. Stop with an outstanding worker, then restart
Implicit execution of `sleep 15; return 83`, with zero wait and no hard timeout:
- Returned **pending** for `session-1-3`.
- The immediately following list showed that session **running**, with `result_available:false`. It also showed the first session idle with its result consumed.
- Stopped Lua without first killing the worker. The actual response was:
  ```json
  {"serverName":"lua","status":"stopped","toolCount":0}
  ```
  This response did not provide per-worker exit confirmation or a terminal execution result. **No preservation or return of `83` is claimed.**

After restart:
- Rediscovered `session_list` and used the **new binding**.
- Listing returned **`sessions:[]`**: prior sessions were not exposed in the new instance.
- `return 42` completed successfully with **`values:[42]`**, proving the new instance usable.
- Killed that newly returned session: **`status:"killed"`**, unusable, **process exit confirmed**.
- Final Lua stop succeeded with `status:"stopped"` and `toolCount:0`.