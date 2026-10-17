# U6 runtime evidence

## Implementation and scope
Based on `8a1aeb9`, Lua 5.4.6 and project-local luaposix 36.3 (the U3-qualified tree).

- `manager.lua` freezes active-generation fatal causes, waits for cleanup before fatal/kill replies, preserves recorded completions, removes live inventory, and exposes `accept(tool,input,request_id)`, `bind(id,handle)` and `cancel(id)`. Binding must occur before transmission. Numeric/string IDs remain distinct. Answered/unknown/completed IDs are inert. Cancellation suppresses its reply; kill cancellation cannot undo cleanup. `disconnect()` stops admission and disposes owned workers. Output adapters must call it on EOF/output failure/shutdown; the full MCP wiring is U8.
- `worker_supervisor.lua` owns deadline arbitration at validated receive time, clamps poll waits, clears completed timers, freezes abort causes, drains at most one frame-bound of currently available bytes (no wait for future data), uses SIGKILL and WNOHANG, and drops terminal workers. At 30 seconds it releases management with false exit confirmation, retaining only numeric PIDs for later opportunistic reaping. Shutdown uses the same cleanup machinery.
- Killing does not undo external side effects or guarantee descendant termination. EOF alone cannot establish why the worker channel closed; it is a transport failure, not an invented OS exit cause. Unconfirmed disposal includes a notice and preserves the originating failure.

## Commands
Run from repository root, with:

```sh
export LUA_PATH='./?.lua;./?/init.lua;./.luarocks/share/lua/5.4/?.lua;./.luarocks/share/lua/5.4/?/init.lua;;'
export LUA_CPATH='./.luarocks/lib/lua/5.4/?.so;;'
lua5.4 tests/u6_deadlines_red.lua
lua5.4 tests/u6_policy.lua
lua5.4 tests/u6_ordering.lua
python3 tests/u6_process.py
python3 docs/check_contracts.py
```

All pass. The original red reproducer is unchanged. New policy coverage maps five fatal causes × confirmed/unconfirmed disposal, completion/kill/commit order, cancellation tool/ID/pending-response states, stale completed deadlines and generation replacement. Ordering coverage maps 15 result/partial/exit/EOF/boundary cases and a validation crossing the boundary. Real fixtures cover infinite Lua, FIFO open blocked in the OS, native sleep, os.exit, signal death, live control-channel loss, independent responsiveness, actual WNOHANG reaping, cancellation, allocation/running/idle disconnect, rejected output commit and empty supervisor inventory. The real supervisor additionally runs an injected unreapable OS model at 29.999/30 seconds, preserving timeout cause and retaining only a PID. Python launches process groups with a 45-second external watchdog, NOFILE cap, disposable directory under SAIVAGE_CARD_WORK_ROOT, and final group cleanup. Twenty-one real committed responses validate against per-tool output schemas.

## Regression commands/results
- `lua5.4 tests/u1*.lua` (each separately), `lua5.4 tests/u2.lua`: pass.
- `lua5.4 tests/u2_review_argument_matrix.lua`, `lua5.4 tests/u2_review_false_arguments.lua`: pass.
- `python3 tests/u2_live.py`: pass (this supplies the input protocol to `u2_host.lua`).
- `python3 tests/u3_posix.py`: seven capability groups pass.
- `python3 tests/u4_presence.py`, `python3 tests/u4_process.py`: presence and 15 process groups pass.
- `lua5.4 tests/u5.lua`, `python3 tests/u5_presence.py`, `python3 tests/u5_process.py`: pass, including 28 schema-validated real responses.
- Contract checker: 14 schemas, seven tools, two discovery results, 23 examples, 125 regressions pass.

Initial attempts: native tests without the local Lua paths failed to import posix, fixed by the environment above. Direct invocation of `u2_host.lua` without its parent protocol failed its close assertion; `u2_live.py` correctly exercises it and passes. Initial U6 Python wrapper mistakenly inherited U5 response validation, then used incorrect schema definition names; corrected to actual per-tool output definitions, now passes. Adding an actual kill reply plus its execution waiter then exposed a genuine status-schema mismatch (`killed` on an execution rather than `failed` with `session_killed`); fixed at the shared freeze primitive and reran. These earlier command failures are not represented as successful verification.

## Integration boundaries
U7 bounds/fairness and U8 full MCP adapter remain separate. The rejected-send seam proves consumption/cleanup policy, not actual partial JSON-RPC socket/stdout transmission. No exhaustive mathematical proof of all schedules is claimed: the ordering suite's exit-first case calls the same bounded drain after a modeled observed exit; actual POSIX exit, fragmented transport and descendant-writer behavior also have U4 process coverage. Future adapters must stop admission and call disconnect on short write/output failure, never retry a stale response preview, and keep pumping cleanup independently of suppressed request replies.
