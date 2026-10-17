# Manager termination and orphan prevention — design addendum

## Required behaviour

The standalone manager must dispose of session workers on client disconnect,
normal return, caught fatal errors, SIGINT and SIGTERM. Manager-only crash or
SIGKILL must not leave indefinitely executing workers orphaned. Worker pipe EOF
alone is insufficient: the blocking worker cannot read EOF inside Lua/native code.

This applies only to the standalone manager. The pure-Lua embedded handler must
not install signal handlers or take ownership of host processes. No public tools,
threads, output capture, or sandbox are added. Existing bounded best-effort
termination rules remain applicable to exceptional unkillable OS processes.

## Graceful shutdown and fatal-error boundary

Install SIGINT/SIGTERM handling before spawning managed processes. Signal handling
must request shutdown through a safe flag/wakeup mechanism, not perform cleanup
inside an asynchronous OS signal context. Qualify the selected binding's signal
delivery and interrupted-poll semantics; shutdown must wake an idle event loop.

At a safe boundary, stop admission and enter one idempotent cleanup path covering
starting, idle and executing workers. Disconnect, repeated signals, and fatal
errors converge on this path without dispatching buffered work. Preserve
protocol-only stdout; report shutdown diagnostics on stderr. Normal EOF exits
successfully, fatal errors nonzero, and signal shutdown uses 128+signal status.

Protect initialization from the first acquired resource, event-loop execution,
response encoding/flushing, and cleanup itself. Track partial construction so
failure cannot strand a worker or descriptor. Preserve the original failure
when cleanup also fails. Do not require client acknowledgement for disposal.
SIGKILL/native crashes cannot execute Lua cleanup and require external ownership.

## Independent POSIX guardian

Use one dedicated single-threaded guardian process per standalone manager. It
owns OS worker spawning/reaping; the manager remains the logical session owner
and retains authoritative deadlines, outcomes and result-consumption semantics.
The guardian does not execute submitted Lua or service public MCP requests.

A manager-only liveness channel lets the guardian observe manager death through
EOF independently of worker execution. Workers and subprocesses must never retain
its write end: explicitly close inherited copies before exec as well as setting
CLOEXEC. Keep liveness separate from worker control traffic and backpressure.

The guardian must own each worker before readiness or user-code execution. Having
the manager spawn and subsequently register a PID creates an unacceptable death
window. Qualify private command channels and descriptor transfer/inheritance on
the pinned POSIX binding before implementing the topology. If descriptor passing
is unavailable, qualify an alternative guardian-owned topology; do not silently
fall back to spawn-then-register. Raise a concrete dependency blocker if needed.

Use private allocation identities and race-safe OS child ownership, not public
PIDs or stale PID-based kill lists. Guardian commands and exit reports refer to
the same allocation. Retain ownership until termination/reaping is resolved;
never signal an unrelated reused PID. Preserve existing outcome-ordering rules.

On manager liveness loss, stop spawning and progressively terminate all owned
workers, including blocked startup and execution, using the policy below. Close
resources and reap boundedly, without serial per-worker delays that multiply the
shutdown bound. No client or Lua worker cooperation is needed.
An exceptional unconfirmed exit must not cause an indefinite guardian hang or a
false claim of successful reaping. Preserve existing user-created output files.

Manager detection of guardian failure must fail closed: stop admission and shut
down, attempting worker disposal only where identity remains safe. Do not kill
possibly reused PIDs. Document the fallback's limitations. Normal shutdown waits
boundedly for guardian disposal; repeated signals must not preempt its cleanup.
Bound guardian commands, queues and descriptors consistently with resource limits.

## Progressive termination policy

All disposal paths use the same nonblocking escalation, including explicit kill,
hard timeout, cancellation, startup failure, transport loss, signal shutdown and
guardian cleanup after manager death:

1. Send SIGTERM immediately; retry every 1 second for at most 20 seconds.
2. If child exit is still unconfirmed, send SIGKILL at the transition and retry
   every 1 second for at most a further 10 seconds.
3. If still unconfirmed at the 30-second total deadline, stop signalling and
   abandon the child as a managed session. Close channels and release session
   capacity; retain only minimal safe eventual-reaping bookkeeping while the
   reaper is alive. A surviving process can still have external side effects.

Stop retries immediately on confirmed child exit, even if normal execution
completed after cleanup began; preserve the established outcome-ordering rules.
Successful signal delivery is not confirmation of exit. Use monotonic deadlines,
no catch-up bursts after scheduling delays, and no deadline resets on repeated
kill/disconnect/signal requests. Shutdown of many workers escalates concurrently.
If manager death transfers ongoing cleanup to the guardian, preserve phase and
original deadline rather than granting another 30 seconds. Guardian ownership
must make retries safe against PID reuse, including a worker exiting between
checks. Reaping and signalling must not race through independent owners.

When a reply can still be delivered, abandonment returns successful best-effort
kill with `process_exit_confirmed: false` and the existing warning; other cleanup
paths preserve their original failure reason and unconfirmed-exit notice.
With no client connection, emit a bounded stderr diagnostic instead. Do not wait
indefinitely for the child, or claim that abandonment terminated it.

## Guarantee boundary

Acceptance requires real evidence that manager-only SIGKILL/abrupt exit leaves
neither idle nor non-yielding session workers running. Lua finalizers, shell traps,
worker polling hooks and optional service units are not sufficient protection.
Linux parent-death signals/cgroups may supplement, not replace, the POSIX design.

Simultaneous manager/guardian death, host/kernel failure, uninterruptible kernel
waits, deliberate interference by fully trusted code, and arbitrary descendant
process trees remain outside the unconditional guarantee. No promise of general
process-tree containment or sandboxing is introduced. In an abrupt crash there
may be no live client connection on which to report unconfirmed termination.

## Acceptance evidence

Use actual processes, readiness/execution barriers, and external watchdogs:

- SIGINT/SIGTERM during idle, blocked startup, infinite Lua and blocking native
  execution: admission stops and workers/guardian terminate within the bound.
- Manager-only SIGKILL and abrupt exit in those states: guardian independently
  disposes of workers and exits. Include the spawn/readiness transition window.
- Failure injection around guardian creation, spawn, readiness and result delivery:
  no unowned child can become ready or execute; partial resources are cleaned up.
- Repeated signals, EOF and completion/kill races: cleanup stays idempotent and
  terminal outcomes are not rewritten.
- Verify SIGTERM-first ordering, repeated TERM and KILL attempts, early exit in
  either phase, and total abandonment deadline with deterministic clocks/fakes.
  Real fixtures include a cooperative TERM exit and a TERM-ignoring worker that
  requires KILL. Simulate KILL-resistant/unconfirmed exit; do not try to create
  an unkillable host process. Verify parallel cleanup and manager-death handoff
  cannot reset or multiply the deadline.
- Worker/subprocess inheritance cannot hold liveness open; guardian loss triggers
  fail-closed handling. Simulate stale allocations and unconfirmed exits safely.
- Clean-installed executable outside the checkout passes the lifecycle cases;
  existing protocol, cancellation, resource-limit and packaging tests still pass.

Record commands, topology/capability findings, versions, process observations and
limits in `docs/validation/MANAGER_LIFECYCLE.md`. Fake-process tests supplement but
do not replace real process evidence.
