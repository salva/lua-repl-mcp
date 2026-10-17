# Independent U12 audit — checkout diagnosis

Review by [[card:card-d-b]] of [[card:card-d-a]]. Product input:
`15a2760d3c5cb121053c9d95be09f7e32340eb5f` (clean initial worktree).

## Verdict

**Not ready for U12 acceptance: observed failing regression.** The real ownership
matrix and focused exceptional-path tests pass independently, but a completed
execution becomes `execution_timeout` when delivery across the guardian relay is
delayed. This violates SPEC §14.6's frozen pre-deadline completion rule and the
design requirement to preserve authoritative manager outcomes. Corrections belong
to the original implementation card; this audit does not change product code.
Clean installation and refreshed U10 evidence are separate gates, not claimed here.

## Required correction (high priority)

`tests/u12_audit_relay_red.lua` reproduces with real guardian and execed worker:
create a session, dispatch a 1MiB return with a 2-second hard deadline, flush the
execute command, suspend manager consumption for 2.5 seconds while the guardian
continues. The fixture verifies the guardian's recorded completion precedes the
original deadline; it then requires a completed manager response. Run with:

```sh
export LUA_PATH='./?.lua;./?/init.lua;./.luarocks/share/lua/5.4/?.lua;./.luarocks/share/lua/5.4/?/init.lua;;'
export LUA_CPATH='./.luarocks/lib/lua/5.4/?.so;;'
lua5.4 tests/u12_audit_relay_red.lua
```

Observed exit **1**, assertion `pre-deadline completion changed by relay delay`.
Guardian completion `878324.38138114`, deadline `878326.16466514`; public response
was failed `execution_timeout`, session terminated, exit confirmed true. The
fixture shuts down the backend before asserting. Primary output:
`work:///cards/card-d-b/processes/proc-046a02f6484f/stdout.log` and
`work:///cards/card-d-b/processes/proc-046a02f6484f/stderr.log`.

Branch analysis: `manager:step` calls `refresh` before backend receive;
`refresh` freezes the deadline against a stale running mirror. Even backend-only
progress has the analogous race: `guardian:B:step` can consume only 64KiB of a
large report before checking the stale mirror deadline. Dirty guards then suppress
completion until a dead report arrives, too late to undo the frozen manager
failure. The independent backend probe showed a pre-deadline `result_at` eventually
present on a dead mirror with `failure=execution_timeout`. This is not worker
execution taking too long. The new relay adds a second observation/validation
boundary that current completion tests do not exercise.

Fix the owning outcome/relay arbitration, not this symptom alone: define consistent
completion-vs-timeout/accepted-kill transitions across partial reports, backlog,
manager scheduling pauses and guardian loss. Preserve the manager's authority,
accepted active-kill freeze, original deadlines and completed-result immutability;
do not simply disable timeouts or unconditionally accept late results. Add real
and deterministic tests of timely and late completion, partial/blocked relay,
queued abort ordering and a completed idle worker subsequently killed. Rerun
lifecycle/resource/cancellation suites after the correction.

## Independent verification completed

Same local Lua/luaposix environment documented in MANAGER_LIFECYCLE.md. All commands
below completed successfully on the product input (the added failing fixture does
not alter runtime inputs):

- `python3 tests/u12_matrix.py`: all **28** named cases passed, including idle,
  acknowledged pre-exec spawn, FIFO startup, infinite Lua and native FIFO blocking
  under INT/TERM/KILL/abrupt exit; descendant liveness isolation, guardian-loss
  fail-closed, EOF, repeated signals, fatal boundaries and TERM-ignore. Ignoring
  workers required ~20.055s /20.016s. Primary result:
  `work:///cards/card-d-b/processes/proc-af04c66f4e16/stdout.log`.
- Fail-fast sequence: `lua5.4 tests/u12_rare_policy.lua`,
  `tests/u12_partial_acquisition.lua`, `tests/u12_channel_stream.lua`,
  `tests/u12_large_frame.lua`, `tests/u12_aggregate_reports_red.lua`,
  `tests/u12_server_boundary.lua`, then `python3 docs/check_contracts.py`.
  All exit0; 19 partial acquisition points, original deadline/parallel disposal,
  stale wait safety, 17MiB private decoding and aggregate capacity covered.
  `work:///cards/card-d-b/processes/proc-3c2db3b81c69/stdout.log`.
- Real Lua fixtures `u12_real_faults.lua`, `u12_identity_races.lua`,
  `u12_aggregate_process.lua`, each in a new process group under external
  25/45/50-second Python watchdogs with own-group containment: all exit0.
  Then `python3 tests/u8_live.py`: all named external conformance checks passed.
  Expected reused/stale allocation guardian diagnostics were not suppressed.
  `work:///cards/card-d-b/processes/proc-aaf8beae5c91/stdout.log` and `stderr.log`.

## Scope and branch review

Read full lifecycle design, PLAN U12, SPEC §§14.4/14.6/14.9, authored lifecycle
validation and primary matrix/identity/rare/fault fixtures; inspected guardian,
channel, native supervisor, manager, POSIX primitives and standalone boundary.
Guardian owns fork before readiness; manager has no worker PID fallback. Separate
liveness pipe closes in guardian/worker inheritance sweep, is polled before relay
turns, and the real descendant barrier supports EOF independence. Streamed batches
retain bounded allocation references and one encoded item, not one aggregate JSON
frame. Receive has a 64KiB turn bound; configured decoder cap is propagated.
SIGINT/TERM request flags precede managed spawn; cleanup is outside callback.
Partial acquisition tracks descriptors/child ownership. Native escalation preserves
origin, uses noncatchup retries, reaps before retries, and stops signals after
wait ownership loss or abandonment. Tests support these branches, not a guarantee
against every syscall/kernel failure.

Existing identity tests wait for mirror completion before killing; therefore their
40 passing iterations do not address the newly observed relay race. Nine-result
aggregate coverage likewise has no deadline during stalled delivery. Large reports
can take multiple turns, so this is a necessary independent adversarial addition,
not a reason to dismiss passing ownership evidence.

Guardian-loss limitation is explicit and tested: admission fails closed, but the
manager cannot safely signal workers after losing guardian child ownership. No
claim of general descendant containment, simultaneous owner death protection or
real KILL-resistant kernel process testing is made. Embedded handler changes were
not required or made. U9 clean-install and U10 checks remain with their assigned
owners. No host/shared-runtime changes, restart, push or publication performed.
