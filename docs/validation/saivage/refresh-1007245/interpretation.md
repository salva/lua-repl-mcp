Completed the trial using **45 tool calls**, exclusively the three permitted MCP tools on `lua`. No project execution, source changes, secret inspection, or shell tools were used.

Discovered all five exact tool schemas. The actual deadline fields are **`wait_timeout_ms`** and **`execution_timeout_ms`**.

### Results

| Scenario | Observed result and interpretation |
|---|---|
| **1. Explicit creation, persistence, isolation** | Created `session-1-1`. Defining `n=40` and `add` completed with `values: []`, consistent with no explicit return. The next execution asserted the values and return count, returning **`[42, null, {"count":2,"tag":"json"}]`**—three values with the middle null preserved. Independent `session-1-2` returned **`[true,true]`** for `n==nil` and `add==nil`. |
| **2. Implicit creation** | Omitting `session_id` created **`session-1-3`**, returning **`[{"kind":"implicit","ok":true}]`** synchronously using an explicit Lua `return`. |
| **3. Async execution and consumption** | Sleep-1 execution with zero wait returned **running**, not a terminal result. Listing subsequently showed completed work with **`result_available:true`**, without consuming it. The short finite wait retrieved **`[73]`**; therefore the following unbounded wait, and the additional wait, both returned **`result_unavailable`** with the session still usable. A subsequent execution returned **`[74]`**. **Timing deviation:** completion occurred before the finite wait, so an unbounded wait did not retrieve the terminal value in this run. |
| **4. Recoverable errors and side effects** | Syntax error: **`lua_syntax_error`**, execution **not_started**, session usable. Runtime error: **`lua_runtime_error`**, execution **started**, session usable. Returning a function: **`result_serialization_error`** at `/values/0`, execution **completed**, session usable; the error explicitly stated side effects were not rolled back. Later assertions returned **`[true,1,1,42]`**, proving the syntax-side assignment never ran, both other counters persisted exactly once, and the original function remained usable. |
| **5. Finite wait and kill** | Initial sleep-2 execution returned running, but the subsequent finite wait already retrieved **`[75]`**. A second bounded sleep-2 execution with a **1 ms execution-call wait** returned running, demonstrating finite wait expiry without immediate termination. The unrelated session returned **`[42]`**. Kill returned **killed**, unusable, with **`process_exit_confirmed:true`**. Waiting afterward returned **`unknown_session`**, not a retained fatal execution result; repeated kill also returned **`unknown_session`**, consistent with kill retaining no history. **Limitation:** the target was last observed running, but may have completed before kill; active-at-kill termination and fatal-result retrieval were not established. |
| **6. Independent hard timeout** | Implicit `session-1-4`, with a 100 ms hard deadline and zero wait, initially returned running; its later unbounded wait returned **`unknown_session`**, so that attempt did not expose a terminal timeout result. A separate implicit execution with the same hard deadline and an unbounded wait returned **`execution_timeout`**, execution started, session terminated/unusable, and **`process_exit_confirmed:true`** for `session-1-5`. The unrelated session still returned **`[42]`**. |
| **7. Independent client deadline** | The sleep-65 call, with both deadlines null, failed with **“timed out after 30000ms.”** It was **not retried**. The immediate list attempt failed because **`lua` was not running**. Thus the observed effect extended beyond a single session; this was **not** a returned Lua `execution_timeout`. After explicitly starting `lua` again and rediscovering fresh bindings, listing returned **`sessions:[]`**, and a newly created session returned **`[42]`**. **Limitation:** continued usability of a pre-existing unrelated session was not demonstrated; only post-restart usability was. The deadline call returned no session ID, and its exact Lua execution/cancellation outcome was not directly observable. |

### Cleanup

After restart, the only listed session was the new usability-check session. It was explicitly killed with confirmed process exit; the final list returned **`sessions:[]`**, and `lua` was successfully **stopped**.

The original sessions were absent after restart, but their individual OS exits were not separately confirmed. Overall, the trial demonstrated persistence, isolation, result consumption, recoverable errors, and explicit hard-timeout reporting, while exposing the timing and lifecycle limitations noted above.

---

Completed in **18 calls**, using only Lua MCP control, discovery, and invocation. No side-effecting execution was retried.

### 1. Finite wait expiry → terminal result → consumption
Implicit execution created `session-1-1` with `wait_timeout_ms=1` and no hard deadline.

- Execute returned **`status:"running"`**, session usable: the finite wait expired without terminating execution.
- Unbounded wait returned **`status:"completed", values:[81]`**, session idle and usable.
- Another wait returned the expected tool error **`result_unavailable`**, with execution state `completed` and session still usable. The terminal result had been consumed.

### 2. Hard deadline captured in the execute request
Implicit execution created `session-1-2`, with `execution_timeout_ms=100` and an unbounded wait.

The execute request itself returned:
- **`execution_timeout`**, stage `execution`, execution state `started`
- `status:"failed"`
- `session_status:"terminated"`, `session_usable:false`
- **`process_exit_confirmed:true`**

This was an explicit hard Lua execution deadline result, not a client invocation timeout. No value `82` was returned.

### 3. Stop with a pending worker; restart
Sleep-15 execution created `session-1-3` and returned **running** with zero wait.

The immediately following list showed:
- `session-1-3`: **running**, `result_available:false`
- Earlier `session-1-1`: idle/completed, `result_available:false`

Without first killing the worker, stop returned:
```json
{"serverName":"lua","status":"stopped","toolCount":0}
```
This confirms the reported server stop; it does **not** independently confirm the worker’s OS exit or preservation of its execution. No terminal result or value `83` was retrieved.

After restart and fresh binding discovery:
- Listing returned **`sessions:[]`**: prior sessions were not exposed by the new instance.
- `return 42` completed with **`values:[42]`**, proving the new instance usable.
- Its returned session ID was killed successfully, with **`process_exit_confirmed:true`**.
- Final server stop succeeded: **`status:"stopped"`**.
