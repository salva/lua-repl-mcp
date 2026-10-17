The trial was **blocked at tool discovery**; none of scenarios 1–7 executed.

- **Start:** `lua` started successfully and reported **5 tools**.
- **Discovery:** All 34 discovery calls returned `success:false` with **“MCP tool not found.”** This included `create_session` and unsuccessful attempts to request an all-tools listing. No schemas or `bindingId` were obtained. The repeated invalid discovery attempts were my error; they did not test Lua behavior.
- **Execution:** No `mcp_tool_call` was made. No session IDs, pending results, terminal results, or Lua errors were returned.
- **Cleanup:** No sessions were created by this trial. I could not list or kill any pre-existing sessions without discovered bindings. **Stopping `lua` succeeded**, reporting `status:"stopped"` and `toolCount:0`.

| Scenario | Observed outcome |
|---|---|
| 1. Persistent globals, nil/count, JSON argument, isolation | Not executed |
| 2. Implicit session and synchronous object return | Not executed |
| 3. Async pending, waits, consumption, reuse | Not executed |
| 4. Recoverable errors and exactly-once side effects | Not executed |
| 5. Finite wait, unrelated session, active kill | Not executed |
| 6. Independent hard timeout | Not executed |
| 7. Client invocation deadline and cancellation effects | Not executed; no 65-second workload was submitted or retried |

**Total: 36 tool calls**, within your limit of 45. I used only the permitted tools; no shell, source changes, secret inspection, or project execution occurred.

The next step is to resolve discovery: the exposed `mcp_tools` schema requires a `toolName`, despite its description saying that name is optional for listing all tools. An available all-tools discovery path or the server’s exact registered tool names is needed before this trial can proceed safely.

---

## Outcome

Executed the trial using **45 tool calls**, only the three permitted tools on `lua`. No shell, source changes, secret inspection, or project execution occurred. **Final session list was empty, and `lua` stopped successfully.**

All five exact schemas were discovered. The actual deadline parameters are **`wait_timeout_ms`** and **`execution_timeout_ms`**.

### 1. Persistent state, JSON arguments, nil, and isolation — verified
- Explicitly created `session-1-1`.
- Defining `n=40` and `add(x)` completed with `values: []`: no implicit return.
- Next execution asserted the calculation and JSON argument, returning:
  ```json
  [42, null, {"tag":"json","value":7}]
  ```
  Exactly **three values**, with the middle Lua `nil` preserved as JSON `null`.
- Explicitly created independent `session-1-2`; assertions that `n` and `add` were absent passed, returning `[true,true]`.

### 2. Implicit session and synchronous object result — verified
Omitting `session_id` created **`session-1-3`** and synchronously returned:
```json
[{"kind":"implicit","value":42}]
```
Its returned ID was retained and reused.

### 3. Async execution and result consumption — verified, with a timing limitation
- `sleep 1; return 73`, with `wait_timeout_ms:0`, returned **`status:"running"`**—a pending, nonterminal result.
- `session_list` subsequently showed execution completed with **`result_available:true`**.
- A finite 1 ms wait returned terminal `[73]`, proving listing had not consumed it.
- The subsequent unbounded wait, and another zero-time wait, both returned **`result_unavailable`**. The session remained idle and usable.
- Another execution on that same session returned `[42]`.

**Limitation:** execution finished before the finite wait; the unbounded wait therefore observed an already-consumed result, not a pending-to-terminal transition.

### 4. Recoverable errors and side effects — verified
All three failures left the session **idle and usable**:

| Test | Returned error | Execution state |
|---|---|---|
| Invalid syntax | `lua_syntax_error` | `not_started` |
| Increment then `error(...)` | `lua_runtime_error` | `started` |
| Increment then return a function | `result_serialization_error`, path `/values/0` | `completed` |

A later valid execution asserted and returned:
```json
[null, 1, 1]
```
Thus the syntax-error chunk produced no increment, while runtime-error and serialization-error increments each persisted **exactly once**.

### 5. Finite wait and kill — partially demonstrated
- First `sleep 2` execution returned pending.
- Its finite 1 ms wait actually returned terminal `[99]`: **wait expiry preserving active work was not demonstrated**.
- An unrelated session returned `[42]`.
- A second bounded `sleep 2` execution returned pending; killing its session returned:
  - `status:"killed"`
  - `session_usable:false`
  - `process_exit_confirmed:true`
- Waiting afterward returned **`unknown_session`**, not a retained fatal execution result.
- Repeated kill also returned **`unknown_session`**, consistent with the discovered “retain no history” contract.

There was no state observation between the second pending reply and kill, so activity at the precise instant of kill is not independently established.

### 6. Independent hard timeout — terminal timeout result unavailable
- An implicit execution used `execution_timeout_ms:100` for `sleep 2`, with immediate pending return.
- It returned ID **`session-1-4`**.
- Unbounded wait returned **`unknown_session`**, with `session_usable:false`.
- The unrelated `session-1-3` still returned `[42]`.

This is consistent with the documented hard deadline destroying the session, but **no explicit timeout terminal result was delivered**, so timeout classification was not directly verified.

### 7. Client invocation deadline — observed server-level disruption
Submitted the 65-second workload **once**, with both deadlines null. It returned:
> `Tool 'session_execute' on server 'lua' timed out after 30000ms`

The next list call failed:
> `MCP server 'lua' is not running`

This was a **client/tool invocation timeout**, not a returned Lua hard-timeout result. No session ID was delivered for that execution, and its exact cancellation/process outcome was not observable.

I started `lua` again and rediscovered bindings:
- Listing returned `sessions: []`.
- A newly created implicit session returned `[42]`.

**Limitation:** unrelated pre-existing session survival could not be proved—the server was unavailable and its new instance listed no sessions. Only **post-restart usability** was demonstrated. The returned session ID was reused by the new instance; it does not establish continuity with the old session.

### Cleanup
Killed the sole session listed in the new instance, with confirmed process exit; final listing returned **`sessions: []`**; stopped `lua` successfully. The original instance’s individual session disposal was not independently observed after the client timeout.

---

Completed in **18 calls**, using only Lua MCP controls, discovery, and calls. No workloads were retried.

### 1. Finite wait expiry and consumption — verified
Implicit execution of `sleep 1; return 81`, with `wait_timeout_ms:1` and no hard deadline:
- Returned **pending**: `status:"running"`, session `session-1-1`, usable.
- Unbounded wait returned **terminal success**: `status:"completed"`, `values:[81]`, idle and usable.
- Another wait returned **`result_unavailable`**, confirming terminal retrieval consumed the result. This was a validation error, not an execution failure; the session remained usable.

### 2. Hard deadline captured in the execute request — verified
Implicit execution of `sleep 2; return 82`, with `execution_timeout_ms:100` and unbounded wait, returned:
- **`execution_timeout`**, stage `execution`, execution state `started`
- `status:"failed"`
- Session `session-1-2`: **terminated and unusable**
- **`process_exit_confirmed:true`**

This was an explicit Lua execution-deadline result—not a client invocation timeout. No value `82` was returned.

### 3. Stop with a pending worker, then restart — observed
Implicit execution of `sleep 15; return 83` returned **pending**, session `session-1-3`.

The immediately following list showed:
- `session-1-3`: **running**, `result_available:false`
- `session-1-1`: idle, prior result consumed
- The hard-timeout session was absent.

Without killing the worker first, stopping Lua returned:
```json
{"serverName":"lua","status":"stopped","toolCount":0}
```
That response contains **no per-worker exit confirmation or result-preservation evidence**. No terminal result `83` was retrieved.

After restart and fresh binding discovery:
- Session listing returned **`sessions:[]`**—old sessions were not exposed by the new instance.
- `return 42` completed with **`values:[42]`**, proving new-instance usability.
- Its returned session ID was `session-1-1`; reuse of that string does not imply continuity with the prior instance.
- Killing it succeeded with **confirmed process exit**.
- Final stop succeeded: **Lua is stopped**.
