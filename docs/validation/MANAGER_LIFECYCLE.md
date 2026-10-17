# U12 lifecycle qualification (in progress)

This is implementation-stage capability evidence, **not U12 acceptance**.
Production code still uses direct manager spawn/reap. The existing lifecycle
reproducer remains red. Independent audit, clean-install lifecycle validation,
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

## Remaining implementation and validation

The qualified alternative is a useful concrete implementation path, not a
product repair yet. Add guardian-owned allocation identities and relay queues,
bounded spawning/admission/descriptors, asynchronous exit reporting, shared
progressive termination state with manager-death handoff, safe fail-closed
handling of guardian loss, and protected standalone construction/shutdown. Keep
logical outcomes/result ordering in manager; keep native ownership out of pure
handler imports. Reuse the existing TERM20/KILL10 monotonic policy rather than
reintroducing old immediate-KILL cleanup.

Then run `tests/u12_lifecycle_red.py` and complete the design's real-process
barrier/watchdog matrix: graceful signals and manager-only crashes during idle,
blocked startup, infinite Lua and native blocking; partial failures and spawn
window; inheritance including subprocesses; repeated signals/EOF/completion
races; guardian loss; cooperative and ignoring TERM. Deterministic clocks/fakes
must cover stale identities, phase boundaries, delayed turns without bursts,
unconfirmed exit and capacity release, concurrent cleanup and original handoff
deadlines. No real unkillable process should be created. Run affected runtime
suites. General descendant-tree containment, simultaneous guardian/manager loss
and exceptional kernel inability to terminate remain outside the guarantee.
