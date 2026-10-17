# U5 — connection-local manager sessions and result commitment

## Implementation and integration contract

Baseline U4: `4c77969`. New reusable `lua_repl_mcp.manager` owns one connection's
sessions. `new({supervisor?,clock?,...supervisor_options})`, `accept(tool,args)`,
`step(ms)`, `preview(request)`, `commit(request,send)` and `disconnect()` are
internal embedding seams, not additional public tools or task IDs. Drive step
while requests are pending. Requests are opaque Lua handles; do not expose them.
The default backend is the real U4 supervisor. Native imports remain outside the
handler tree; deterministic tests inject a backend/clock without native modules.

`accept` validates/clones the complete contract before allocating. IDs are opaque
connection-local monotonically unique strings, never reused even across manager
instances in the same interpreter. Explicit/implicit allocation shares one path.
Dispatch reserves a new policy execution/generation and wait/hard deadline before
backend command admission; the supervisor reserves running before any step writes.
Idle validation/admission errors preserve the prior result. Busy/terminating
rejections do not dispatch or mutate it. Allocation completion is serviced by step,
not contingent on a transport repeatedly previewing the response.

Each request is bound to its original execution object. At replacement the old
payload is discarded; old waiters retain only lightweight terminal status, not a
history address. Current live terminal payloads have no TTL. Listing snapshots
observe but never consume, and dead entries are removed rather than tombstoned.
Worker readiness now carries effective initial cwd; supervisor exposes it to the
manager. The new cwd field is optional only for compatibility with U4 synthetic
protocol fixtures; production workers always report absolute effective cwd.
Creation path NULs are rejected by the owning contracts primitive before fork.

`preview` is NOT authorization to transmit a terminal payload. `commit` rechecks
availability and calls `send(response)` synchronously: the callback must budget
check/encode and atomically enqueue that exact response, returning true only once
committed. False/exception consumes nothing. A true return consumes even if the
peer disconnects immediately afterward. Callback must not yield or reenter manager;
reentry is guarded. Multiple previews may see a payload; only one committed
response obtains it, including initial execute versus explicit wait. Other waiters
get result_unavailable and terminal execution status. No public task IDs/queue.

## Named U5 acceptance mapping

`tests/u5.lua` deterministic groups:

| Group | PLAN U5 branches covered |
|---|---|
| validation_allocation_starting_idle_unknown_none | Complete validation before allocation (including false options, NUL path, invalid timeouts), unknown vs no-execution, starting/idle list snapshots |
| zero_pending_retention_budget_commit_single_consumer | Zero execute pending even at immediate completion; no TTL; list availability; failed/throwing commit preserves result; two previews, one committed payload; exactly once |
| successful_failed_waiters_execute_compete_and_rejected_preserves | Success/error retention; initial execute plus two explicit waiters; invalid execution preserves old result; consumed terminal status |
| positive_wait_origins_defaults_busy_preserves | Dispatch-relative execute vs acceptance-relative wait; positive expiry doesn't kill; omitted defaults both 600000; busy rejection preserves generation; running list |
| expired_wait_does_not_consume_late_completion | Late completion does not extend finite wait or consume result |
| replacement_old_generation_waiters_no_history | Replacement discards previous payload; outstanding execute/wait cannot receive new payload |
| implicit_dispatch_origin_actual_error_id_terminating_removal | Implicit readiness delay excluded from execute wait; step-driven dispatch; actual ID on retained error; terminating rejection/list; dead removal; IDs not reused |
| commit_before_disconnect | Commitment consumes before disconnect; no delivery assumption |

`tests/u5_process.lua`, invoked by Python process-group watchdog, uses actual
fork/exec U4 workers, persistent Lua globals and real nonblocking pipe I/O:

- `real_two_worker_responsiveness_busy_exactly_once_waiters_listing`: one worker
  sleeps while the other completes; busy rejection; two waiters; persistent counter
  confirms exactly once; running and idle list snapshots.
- `real_implicit_error_id_retained_error_rejected_execute_commit_race`: implicit
  pending actual ID, Lua runtime error retention, invalid dispatch preservation,
  failed budget commit, one error consumer, later unavailable status and reuse.
- `real_old_waiters_replacement_commit_before_disconnect`: old outstanding execute
  and wait receive unavailable, not replacement values; result consumed before cleanup.
- `real_creation_failure_does_not_claim_execution`: invalid cwd allocation failure
  omits session metadata and does not claim code dispatch.
- `real_wait_modes_deferred_implicit_effective_cwd_unknown_id`: implicit execution
  progresses without preview polling, null/positive/zero wait paths, effective
  relative cwd, unknown-ID response metadata.

The Python driver validates **28 committed real responses** against the applicable
API output schemas. Deterministic tests additionally cover starting/terminating
states without relying on timing luck. The red presence reproducer is preserved
unchanged and now passes; it is not used as a substitute for behavioral evidence.

## Commands and actual verification

Lua **5.4.6**, Python **3.12.3**, luaposix **36.3** (local rock **36.3-1**),
bit32 **5.3.5.1-1** from the existing U3-qualified project dependency tree.
From checkout, commands run with fail-fast shell sequencing:

```sh
lua5.4 tests/u5.lua
python3 tests/u5_presence.py
eval "$(luarocks --lua-version=5.4 --tree=.luarocks path)"
python3 tests/u5_process.py
python3 tests/u4_process.py
python3 tests/u3_posix.py
for t in tests/u1.lua tests/u1_diagnostic_notice.lua tests/u1_public_entrypoint.lua \
 tests/u1_review_invalid_key.lua tests/u2.lua tests/u2_handler_entrypoint.lua \
 tests/u2_review_argument_matrix.lua tests/u2_review_false_arguments.lua; do
 lua5.4 "$t"
done
python3 tests/u2_live.py
python3 docs/check_contracts.py
git diff --check
```

All completed with exit 0. U4 **15** real groups, U3 **7**, U1/U2 regression
fixtures and live pipe test pass. Contract checker reports **14** standalone
schemas, **7** official tools, **2** discovery results, **23** examples,
**125** regression cases. U2 explicit-false-arguments default fix was inspected
and its regression rerun: invalid close does not stop admission. No handler or
protocol default edits were needed. Focused U5 tests were rerun after final manager
changes (all deterministic groups and all 28 schema-checked real responses pass).

## Local review findings and remaining integration

Review caught and fixed: implicit dispatch depending on response-preview polling;
unknown-session metadata missing supplied ID/usable false; creation validation
allowing NUL to reach supervisor assertion; finite waits accidentally extended by
a late completion; relative cwd listed verbatim instead of effective cwd. These
were owning-layer corrections, not suppressed tests. Deterministic and real
regressions cover these paths.

**U6 remains required:** enforce armed hard execution deadlines, cancellation,
full kill success/exit-confirmation response semantics, timeout/response ordering
at exact receive boundary, disposal and fatal-error fanout, and definitive cleanup
integration. Current `session_kill` is provisional abort/error plumbing, NOT U6
acceptance. Current hard deadline is recorded before dispatch but not enforced.
U4 retains its worker inventory/provisional shutdown policy; full retention/resource
cleanup belongs to U6/U7. Normal live result semantics are delivered here.

**U7 remains required:** global/session admission and bounded inventory, response
budgets and bounded encoded transport. Inject the actual preflight/enqueue through
commit; returning true without real budget/enqueue is not a valid integration.
**U8 remains required:** manager MCP framing/event-loop adapter, JSON-RPC request
correlation and cancellation wiring. This is a manager core, not a standalone MCP
entrypoint, packaging or end-to-end client acceptance claim.
