# U12 lifecycle qualification (in progress)

This is implementation-stage evidence, **not full U12 or release acceptance**.
Standalone now uses guardian-owned spawn/reap; the preserved focused lifecycle
reproducer passes. Independent audit, clean-install lifecycle validation,
and real-agent refresh are not claimed.

## Exact input and environment

Starting revision: `22a6ba9` (red reproducer on product revision
`13b020a0470bd863670739d53079a634fd7d8645`).
Lua 5.4.6, luaposix 36.3, Python 3.12.3; Linux dedicated project container.
Project-local dependencies are selected explicitly:

```sh
export LUA_PATH='./?.lua;./?/init.lua;./.luarocks/share/lua/5.4/?.lua;./.luarocks/share/lua/5.4/?/init.lua;;'
export LUA_CPATH='./.luarocks/lib/lua/5.4/?.so;;'
lua5.4 tests/u12_topology.lua signal
python3 - <<'PY'
import os, subprocess, signal
p = subprocess.Popen(['lua5.4', 'tests/u12_topology.lua'], start_new_session=True)
try:
    status = p.wait(timeout=27)
    assert status == 0, status
finally:
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
PY
```

## Observed capability results

- `PASS signal_poll_boundary`: SIGTERM callback executed at interrupted poll
  return, `nil, Interrupted system call, errno 4`, elapsed 0.100 seconds for a
  5-second idle poll. The test callback only sets a flag. This supports safe
  shutdown requests outside asynchronous cleanup, not arbitrary work inside a
  signal handler. Races before entering poll still require a bounded poll or
  a qualified wakeup descriptor in the production event loop.
- Pinned socket module provides `socketpair` but no `sendmsg`/`recvmsg`; direct
  SCM_RIGHTS transfer is not available through this module. No manager-owned
  spawn/register fallback is acceptable or needed.
- `PASS guardian_owned_exec_relay_private_liveness_TERM20_KILL10_original_deadline`:
  executable alternative topology uses private Unix stream socket pairs and a
  separate pipe for liveness. Guardian forks worker, closes manager-only ends
  before forking, worker closes all unrelated descriptors before exec and sets
  only its intended endpoint non-CLOEXEC. Execed worker reports PID/PPID after
  setting TERM ignore. Parent verifies PPID equals guardian before proceeding.
- Guardian begins cleanup before parent closes liveness writer. Independent EOF
  is acknowledged while execed worker is still alive and ignoring TERM. Guardian
  preserves original start time, sends 20 TERM attempts and one KILL, confirms
  reap, reports `disposed:20.000:20:1`, and exits status zero. There is no
  spawn-then-register window, no liveness dependency on worker cooperation, and
  no new 30-second grace period at handoff.
- The external watchdog contains only the test's own new process group.
  Production topology must relay bounded worker protocol frames through the
  guardian; this probe qualifies private bidirectional socket transport and
  inherited endpoint isolation, not full frame routing/backpressure correctness.

## Production implementation attempt

`guardian.lua` is the standalone backend, using `guardian_channel.lua` private
bounded newline JSON request/report transport. One in-flight batch plus at most
1024 queued commands, one bounded frame per direction, and admission-limited
allocations bound resources. Guardian alone calls the existing native supervisor
for fork, signal and reap. Manager retains logical mirrors, execution generations,
accepted kill/deadline outcomes, and public result-consumption policy. Dirty
mirrors prevent stale reports overwriting locally accepted transitions. Allocation
IDs are monotonic connection-local integers; no worker PID is sent to manager.

Guardian closes unrelated manager descriptors before worker creation. Worker
resets inherited INT/TERM dispositions before setup/exec (an initial execution
showed inherited guardian TERM-ignore caused a needless 20-second delay). Separate
liveness EOF is checked independent of report backpressure. Guardian continually
steps all children even while reports are blocked; original abort timestamps are
carried in commands and preserved on EOF handoff. Channel loss fails closed with
unconfirmed status, never a stale PID kill fallback. Partial standalone server
construction is protected and cleanup errors do not replace the original error.
Signal callbacks only record the first signal; bounded 5ms polling covers the
before-poll race. Frame callbacks stop admission after shutdown is requested.
Embedded handler is unchanged. Rockspec includes the two new modules.

Using the environment above, ran:

```sh
python3 tests/u12_guardian_process.py
python3 tests/u12_lifecycle_red.py
python3 tests/u8_live.py
lua5.4 tests/u6_progressive_policy.lua
python3 docs/check_contracts.py
git diff --check
```

The first four passed sequentially after implementation (including six real
signal/crash cases across idle/infinite Lua, correct 130/143 statuses, guardian
PPIDs, cancellation, execution deadlines, 256-wait saturation, FIFO startup
cancellation, disconnect reaping and output retention). Contract validation passed
14 standalone schemas, 7 tools, 23 examples and 125 regression cases. U8 initially
failed its old direct-child oracle: it was observing the persistent guardian as
if it were a per-session worker. Updated that oracle to observe guardian children;
no behavior assertion was removed. The preserved U12 reproducer is unchanged.

## Aggregate-capacity repair (after d917a2f)

The unchanged `tests/u12_aggregate_reports_red.lua` now passes. Owning channel
primitive streams a logical batch as `{items={one_item}, done=boolean}` frames;
an empty batch sends one final empty frame. `busy` includes unencoded pending
items, not just the current encoded frame. Only one item/frame is encoded at a
time, with the original complete-response bound; the aggregate is never encoded
or granted an enlarged cap. Retained report references are admission-bounded.
Guardian steps native children and checks the independent liveness pipe between
flush turns even when output is blocked. Receive retains the existing 64KiB turn
budget. Encoder/decoder depth supports configured nesting up to 512 plus private
envelope headroom, rather than the previous hardcoded 160.

Guardian assembles at most 1024 command fragments and applies the batch only on
its final marker, preserving previous command-transition ordering. Manager keeps
`inflight` until final report, applies each allocation report progressively, and
retains dirty-local-transition guards. Empty poll batches still complete. New
commands are not sent during a partial report and cannot interleave snapshots.

Using the environment above, all these checks passed:

```sh
lua5.4 tests/u12_aggregate_reports_red.lua
lua5.4 tests/u12_channel_stream.lua
# Run the following under an external 50s process-group watchdog:
lua5.4 tests/u12_aggregate_process.lua
```

Named results: `multiple_legal_maximal_results` (nine exact 1MiB values under an
8MiB frame cap); `guardian_stream_order_partial_write_EAGAIN_one_completion_empty_bound_single_overflow`
(30 fragments, strict order, one final marker, empty batch, 113-byte writes,
79-byte reads, EAGAIN and unchanged single-item overflow rejection); and
`real_guardian_nine_maximal_results_survive_aggregate_frame_boundary` (nine real
execed workers, each returns V bytes, then two complete retained-result snapshots
exceeding a single frame in aggregate, followed by confirmed shutdown). External
watchdog returned zero and contained only its own isolated process group.

Reran the six-case lifecycle tests, full U8 external suite, deterministic native
progressive policy and contracts sequentially with fail-fast chaining: all passed.
No assertion was removed from the preserved aggregate reproducer.

## Remaining validation / limitations

Full accepted U12 remains incomplete despite both focused reproducers passing.
Guardian allocation
construction still needs fault-injection proof around every partial fork/FD
acquisition. Minimal eventual reaping follows the existing native supervisor;
shutdown unconfirmed diagnostics and exceptional wait failures need dedicated
coverage. These are explicit residual engineering gaps, not release acceptance.

Complete the design's real-process
barrier/watchdog matrix: graceful signals and manager-only crashes during idle,
blocked startup, infinite Lua and native blocking; partial failures and spawn
window; inheritance including subprocesses; repeated signals/EOF/completion
races; guardian loss; cooperative and ignoring TERM. Deterministic clocks/fakes
must cover stale identities, phase boundaries, delayed turns without bursts,
unconfirmed exit and capacity release, concurrent cleanup and original handoff
deadlines. No real unkillable process should be created. Run affected runtime
suites. General descendant-tree containment, simultaneous guardian/manager loss
and exceptional kernel inability to terminate remain outside the guarantee.

## Partial acquisition repair

Native `allocate` now tracks every acquired descriptor inside a protected
boundary, records child PID ownership before fallible parent setup, closes all
partial descriptors on failure and uses the same progressive abort path for an
already-forked child. Pre-fork exceptions become `spawn_failed`, with the original
injected setup message retained; no fictitious exit confirmation is generated.
Guardian endpoint nonblocking/CLOEXEC setup now completes before fork, so those
exceptions cannot create an untracked guardian. Its child close-sweep/entrypoint
is protected and always exits through `_exit` on error (never returns into the
manager's copied call stack).

`lua5.4 tests/u12_partial_acquisition.lua` passed 19 injected parent-boundary
cases: native first/second pipe, four CLOEXEC calls, fork, two post-fork
nonblocking calls; guardian pipe/socketpair, five CLOEXEC calls, two nonblocking
calls and fork. Real FD counts before/after match. No fake PID reaches native
kill/wait: fake child ownership verifies post-fork failures enter termination,
retain the child and confirm reap only on fake wait confirmation. These tests
are deterministic supplements, not real fork-failure or unowned-child process
proof. Remaining child-side readiness/result-delivery injections and full matrix
are still required. After this change the six lifecycle cases, U8, progressive
policy, unchanged aggregate reproducer, streaming regression and contracts passed.

## Extended process matrix and rare disposal states

Using the same environment, `python3 tests/u12_matrix.py` passed 20 real-process
cases: SIGINT/SIGTERM/manager-only SIGKILL/abrupt `_exit(77)` each during idle,
FIFO-open startup, infinite Lua and native FIFO-open execution; plus abrupt exit
with a live shell-created sleep descendant, guardian loss, repeated TERM during
native blocking and EOF during infinite Lua. Successful create, worker execution
file and Linux `/proc/<worker>/syscall` open-state observations establish barriers;
manager wait is bounded at 34s and worker/guardian observation at 32s. Only test
process groups are force-contained. Guardian loss asserts nonzero fail-closed
manager status/diagnostic, NOT worker disposal: safe worker identity is unavailable
after guardian death, and the test contains that documented limitation.

`lua5.4 tests/u12_rare_policy.lua` passed original-origin handoff at 19.5s, KILL
transition at20, abandonment at30 despite repeated requests, bounded unconfirmed
stderr notice, PID-only eventual reaping without further signals, already-expired
handoff with no late signal, and wait-ownership loss with no stale-PID signal.
The native abort primitive now accepts original origin before sending its first
signal (previously guardian adjusted origin only after that signal, allowing a
late TERM after original deadline). Wait failure drops unsafe PID ownership.
Guardian allocation high-water identity rejects reuse even after release.

Fail-fast command (all exit0): rare policy, partial acquisition, progressive
policy, 20-case matrix, full U8, unchanged aggregate reproducer, streaming test,
contracts and diff check. Simulated progressive abandonment writes two expected
unconfirmed diagnostics; those are not test failures. Versions unchanged.

Remaining: explicit real spawn-before-readiness death barrier, stronger live
subprocess-inheritance barrier (current shell spawn is only commanded, not
independently acknowledged), child-side readiness/result delivery fault injection,
real post-fork setup injection, deterministic guardian stale-command/reused-ID
coverage and repeated completion/kill ordering stress. Full U12 remains incomplete;
these additions do not claim clean-install/audit/U10 or release acceptance.

## Completion of previously named process/identity gaps

On product revision `679abe5` (production code unchanged in this continuation),
expanded `tests/u12_matrix.py` now passes **28** cases. New pre-exec test wrapper
is inherited by the guardian child and pauses immediately before worker exec,
after reporting the child's PID. SIGINT/SIGTERM/manager-only KILL/abrupt exit are
all exercised at this acknowledged spawn-before-readiness barrier. The subprocess
case now waits for the descendant shell's PID file and confirms the same live
identity both before manager death and after worker/guardian disposal. Thus a
living execed descendant demonstrably does not retain manager liveness. The test
contains that descendant afterward; no process-tree containment promise is made.
Added repeated TERM and manager-only KILL of a worker that installs TERM-ignore
before its execution barrier: disposal measured 20.058s and20.010s, respectively,
requiring KILL. Caught fatal event-loop errors during native execution and blocked
startup return1 and dispose workers/guardian. Existing normal EOF and protocol
stdout assertions remain. Matrix watchdogs and own-group containment unchanged.

New `tests/u12_real_faults.lua` passes four real-fork failure paths under a25s
external group watchdog: post-fork parent nonblocking exception, child setup
exception, partial readiness delivery followed by death, partial result delivery
following actual execute command followed by death. Every child is confirmed
reaped, parent channels closed, and no partial result becomes consumable.

New `tests/u12_identity_races.lua` passes under45s watchdog:20 complete-result then
repeated kill/shutdown transitions retain completed values;20 active execute then
abort transitions preserve original failure and origin; injected reused allocation
and stale execute after release both fail closed. The expected guardian diagnostic
identifies `reused allocation` or `stale allocation`; no worker PID fallback is
used. The existing rare-policy test now also covers eight concurrent disposals
sharing one original deadline and confirmed exit during KILL phase stopping all
retries. `tests/u12_server_boundary.lua` passes transport-construction/loop/cleanup
injection with one cleanup attempt and original failure preserved when cleanup
also fails.

Commands with the environment above (all completed):

- `python3 tests/u12_matrix.py` —28PASS; then rare policy/contracts/diff check0.
- Real fault and aggregate-process fixtures in isolated subprocess groups under
  25s/50s watchdogs —both0; nine maximal retained results remain valid.
- Identity-race fixture under45s watchdog —0, expected injected failure diagnostics.
- `python3 tests/u4_process.py && python3 tests/u5_process.py && python3 tests/u12_lifecycle_red.py && python3 tests/u12_guardian_process.py` —0.
- `python3 tests/u6_process.py && python3 tests/u7_process.py && python3 tests/u6_progressive_process.py && python3 tests/u8_live.py && python3 docs/check_contracts.py` —0.
  Includes20MiB configured result,16MiB default maximum,256 wait saturation,
  nonblocking stopped-reader cleanup, configured limits, TERM-resistant real
  child (20.011s), cancellation/deadline/output retention and API schemas.
- All then-existing43 selected `u[1-7]*.lua` non-process/host fixtures —driver0.
  This pattern also selected U12 Lua tests; the only expected exit1 remains
  `u7_coupled_defaults_red.lua` which hardcodes obsolete64MiB response capacity,
  as documented by the existing U9 driver. Current128MiB default boundary tests
  pass. Injected stale/abandonment diagnostics are expected and not suppressed.
- New server boundary3PASS; final `git diff --check`0.

This closes the concrete missing checkout process/evidence cases listed in the
previous section; it does not grant independent audit, clean-install validation,
U10 refresh or final release acceptance. Those remain separate follow-up gates.
POSIX guardian-loss fallback cannot safely kill reparented workers after loss of
child ownership; simultaneous manager/guardian failure, arbitrary descendants,
trusted interference and exceptional kernel unkillability remain outside the
stated guarantee. Linux `/proc` is used by tests only. No host/service configuration,
shared runtime, embedded handler, publication or push changes were made.

## Final configured decoder boundary correction

Branch review after the matrix found private receive checked the configured frame
bound before storage but called JSON decode with only depth, inheriting codec's
16MiB public input default. This could still reject a legal larger single private
report despite aggregate streaming. Owning channel now passes `max_bytes=ch.limit`
to decode (no capacity expansion). `tests/u12_large_frame.lua` delivers17MiB payload
through the real receive parser with20MiB configured frame bound and passes.
Fail-fast large-frame + unchanged aggregate reproducer + streaming + full U8 +
contracts + diff-check completed0 after correction. Nine-real-worker aggregate
snapshot fixture reran under50s watchdog and completed0. Prior lifecycle/ownership
results apply unchanged: only decoder capacity argument changed, not native
ownership, command transitions, signal handling or cleanup policy.

## Relay deadline arbitration repair (independent audit follow-up)

The independent audit's original protected regression is preserved unchanged.
It exposed two competing timeout owners: manager refresh (including admission)
and guardian-backend mirror step could both freeze timeout before consuming a
pre-deadline guardian-validated result. A tiny result also failed, excluding a
large-frame-only explanation. Merely receiving before refresh would not fix
partial reports; draining without a budget or extending deadlines is not valid.

The guardian backend now declares `owns_execution_deadlines`: its native child
supervisor is the receive/validation and hard-deadline arbiter. The manager still
assigns the original absolute deadline at dispatch and validates received result
 timestamps against it, but never infers timeout from a stale guardian mirror.
Non-guardian backends retain existing manager-clock behavior. Native guardian
stepping continues independent of relay backpressure: infinite executions still
time out at the original deadline, even if no client/manager can consume reports.
Late/equal timestamped results are explicitly rejected by manager refresh too.
No receive budget, signal policy, cleanup deadline or queue bound is relaxed.

Accepted active kill/cancellation still freeze immediately in manager policy and
mark mirror transitions dirty; subsequent completion cannot rewrite that cause.
Once the manager has accepted completion, killing its idle worker changes session
lifecycle only. Guardian loss remains fail-closed with no PID fallback; a result
not yet relayed is not falsely claimed delivered. This is original U12 correction,
not independent acceptance or clean-install/U10 refresh.

New regressions: `tests/u12_relay_policy.lua` deterministically exercises12
before/exact/after timestamp cases across refresh/admission/step/accepted kill,
plus completed-result kill retention. `tests/u12_relay_order.py` bounds real
`u12_relay_order.lua` in an isolated process group under55s: tiny delayed result,
partial backend report after deadline, queued active kill, completed-idle kill,
actual infinite hard timeout and guardian loss. Partial report uses an observed
nonempty input buffer barrier, not an assumption that one poll turn receives
bytes. Earlier exploratory one-turn assertion failed because an empty prior
snapshot could be consumed first; corrected harness observes actual partial data.
Product correction was not changed to mask that fixture issue.

Repair verification (Lua5.4.6, luaposix36.3, Python3.12.3, recorded local paths):
- Unchanged `python3 tests/u12_audit_relay.py`:0, completion879214.34998583
  < deadline879216.0951133, completed public payload.
- New relay policy/order tests:12 deterministic boundary cases and six real
  guardian scenarios PASS under55s external process-group watchdog.
- Existing28-case lifecycle matrix and full U8 PASS; native U6 ordering15
  validation/EOF/exit permutations, deadlines, policy and U5 deterministic groups
  PASS. Contracts14 schemas/7 tools/2 discovery/23 examples/125 cases PASS.
- Real identity40 races/stale commands and nine-worker aggregate snapshot tests
  PASS under45s/50s watchdogs. Expected stale allocation diagnostics retained.

Verification anomalies are not erased: initial combined command named nonexistent
`tests/u5_policy.lua` after all preceding tests passed; corrected to `tests/u5.lua`
and reran contracts/diff and the focused fail-fast sequence. A U6 native process
run failed with `transport_error` instead of `worker_exited`; isolated rerun and
three repeats passed. A disposable archive of unchanged pre-repair2d6f8d1 reproduced
that same exit-classification race once in10 runs (`exit:transport_error`). Thus
this is a pre-existing native EOF-vs-wait classification issue, not proven repaired
or waived by passing reruns, and is outside this relay-only correction. Native
supervisor and that fixture are unchanged. Initial baseline extraction named an
absent root module and failed before running; corrected archive excludes it.
