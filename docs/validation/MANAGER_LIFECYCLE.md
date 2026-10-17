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

## Remaining validation / limitations

Full accepted U12 remains incomplete despite the focused reproducer passing.
The current aggregated report has a connection response-size cap, not a proven
fit for many simultaneous maximal results; queue backpressure currently fails
closed rather than streaming all legal multi-session maxima. Guardian allocation
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
