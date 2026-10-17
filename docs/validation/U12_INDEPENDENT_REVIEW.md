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

## Repair-node continuation: contain and strengthen the audit fixture

The accepted brief assigns original-scope product corrections to the original
implementation card. Accordingly this continuation does **not** change manager,
guardian or deadline semantics. It repairs weaknesses in the audit fixture:
all setup/barrier/assertion failures now converge on protected backend cleanup,
the execute-flush loop has a watchdog, successful responses must contain the
unchanged 1MiB payload, and `tests/u12_audit_relay.py` bounds the complete isolated
process group externally at45s. This wrapper preserves the Lua exit status and
contains only its own test group on every path.

With the same environment above, run `python3 tests/u12_audit_relay.py`.
On product code unchanged from the prior audit (documentation HEAD `d48cf1d`),
it completed exit1: `response_status=failed error=execution_timeout`, guardian
completion878584.34063064 before deadline878586.12856899. The pre-deadline
fixture check passed; the expected completion assertion still failed. Primary
outputs: `work:///cards/card-d-b/processes/proc-793eb8a76c5b/stdout.log` and
`work:///cards/card-d-b/processes/proc-793eb8a76c5b/stderr.log`.
`git diff --check` passed. Earlier ownership successes apply to unchanged product
inputs but are not acceptance of this regression. Required useful next attempt:
route the owning outcome/relay arbitration repair described above to the original
implementation card, then rerun this externally bounded fixture and ordering suite.
No test assertion was weakened to make the faulty behavior pass.

## Second repair-node investigation: small-report control

Product inputs remain unchanged at `2175ba1`. To distinguish partial-frame
backpressure from manager pre-receive ordering, a disposable copy of the protected
fixture changed only the returned/expected string length from1048576 to1. It ran
under the same45s isolated-process-group watchdog, retaining the2s deadline and
2.5s consumer pause. This **also failed exit1**: response `execution_timeout`,
guardian completion878657.84159165 before deadline878659.83565927. Primary evidence:
`work:///cards/card-d-b/processes/proc-6f518b7d3e24/stdout.log` and
`work:///cards/card-d-b/processes/proc-6f518b7d3e24/stderr.log`.

This materially narrows the correction: a large partial frame is **not necessary**
for failure. A tiny already-available completion loses because manager refresh
freezes a stale running mirror before backend consumption. Fixing streaming alone
or extending the fixture deadline does not address that branch. Partial-frame
arbitration remains additional required coverage, not the sole cause. Both
fixture-cleanup weakness and maximal-payload-only explanations are exhausted;
neither changes the public failure after timely guardian validation.

The accepted audit brief explicitly routes original-scope product corrections to
the original implementation card. There is no remaining test-only repair that can
make this valid completion assertion pass without weakening the specified outcome.
Required decision/input is explicit authorization to edit owning product arbitration
here, or delivery of the original implementation owner's correction. This node
does not assume either and does not wait for another node. Independent verdict
remains reject pending correction; no claim of engineering impossibility is made.

## Resumed independent audit — fixes af80aa9 and 9f82e55

**Current verdict: accept checkout ownership/outcome coverage for focused workflow
verification; not full U12/release acceptance.** This supersedes the earlier
checkout rejection and scope blocker only: the original implementation owner has
now supplied the product repairs. Input HEAD
`9f82e5502157116db3a2a8f256e162ae0994110f`, initially clean. Read current owner
status v47 and inspected both source diffs and primary fixtures independently.
No product source or preserved relay reproducer was changed by this audit.

Relay review: manager still assigns the absolute dispatch deadline and retains
public generation, accepted-kill and consumption policy. The guardian's native
supervisor is now the sole receipt/deadline arbiter for this backend; a stale
running mirror cannot create a second timeout. Native receive checks the deadline
before accepting completion; equality/late completion is rejected. Manager still
rejects a late timestamp defensively, while nondelegated backends keep their prior
clock arbitration. Active accepted kill still freezes the manager outcome; killing
an already completed execution retains it. Private relay partial reads therefore
do not reset deadlines or become evidence of ongoing execution. Guardian stepping
and deadline enforcement continue while report output is blocked. Guardian loss
still fails closed without an unsafe worker PID fallback. This delegation does
not transfer public result consumption or create a new execution grace period.

EOF review: actual empty read marks control_eof, suppressing further pending
writes; EBADF/local channel failure remains transport_failed. Bounded drain and
valid result processing still precede exit classification. Same-turn or later
wait gives the same logical worker_exited for remote endpoint loss, but only wait
provides confirmation/status/reason. Startup remains handshake_failed. Existing
accepted timeout/kill/corrupt causes cannot be rewritten, and complete results
remain available on subsequent idle loss. Reap precedes retry; the new flag does
not change TERM/KILL schedule, original handoff origin or abandonment deadline.

### Fresh independent commands and observations

Use the LUA_PATH/LUA_CPATH environment at the top of this report. All following
checks completed exit0; commands within each sequence were fail-fast.

1. `python3 tests/u12_audit_relay.py` — preserved regression now PASS; completion
   879901.43570921 < deadline879903.20711001, response completed with payload intact.
   `python3 tests/u12_relay_order.py` — six real cases PASS: tiny, partial backend,
   accepted kill, completed kill, hard timeout, guardian loss.
   `lua5.4 tests/u12_relay_policy.lua` —12 deterministic boundary/order cases PASS.
   `lua5.4 tests/u6_eof_wait_red.lua` —6 empty/partial/complete × same/next-turn
   cases PASS. `python3 tests/u12_matrix.py` —28 barrier/watchdog cases PASS;
   TERM-ignore disposal20.025s/20.017s. Complete output read from
   `work:///cards/card-d-b/processes/proc-024623e2fb5a/stdout.log`.
2. `python3 tests/u6_process.py` **five consecutive times** — all PASS, including
   native os.exit/signal vs local-channel closure and 21 schema-checked committed
   responses per run. Then Lua u6_progressive_policy, u12_rare_policy,
   u12_partial_acquisition, u12_server_boundary, u12_channel_stream,
   u12_large_frame, u12_aggregate_reports_red; `python3 tests/u8_live.py`;
   `python3 docs/check_contracts.py` —all PASS. Simulated unconfirmed-disposal
   diagnostics are expected and retained, not actual leaked-process evidence.
   Complete stdout read from
   `work:///cards/card-d-b/processes/proc-6ed4744ab5b2/stdout.log`; stderr confirms
   contracts14 schemas/7 tools/2 discovery results/23 examples/125 regressions.
3. Real u12_real_faults, u12_identity_races and u12_aggregate_process fixtures in
   isolated process groups with external25/45/50s watchdogs —all PASS.
   `work:///cards/card-d-b/processes/proc-23c48b6f0cfc/stdout.log` and stderr
   (expected stale/reused allocation fail-closed diagnostics).
4. New independent `lua5.4 tests/u12_audit_eof_policy.lua` —three PASS. A real pipe
   EOF with mocked wait0 remains unconfirmed through TERM/KILL/30s abandonment;
   local EBADF stays transport_failed; preaccepted timeout stays timeout. No exit
   reason/status invented, original failure retained, eventual bookkeeping never
   signals an abandoned PID. Fake PID never reaches native wait/signal.
   `work:///cards/card-d-b/processes/proc-5b2c277f7b0e/stdout.log`.

### Remaining gates / explicit limits

No new checkout correction required by this audit. Earlier ownership review plus
fresh full matrix, real fault/identity/aggregate and deterministic escalation
coverage support pre-readiness ownership, partial construction, descriptor
inheritance, safe signals, fail-closed loss, bounded channels and progressive
cleanup across cancellation/deadline/disconnect/shutdown. New source diffs do not
change these primitives except EOF classification; they were nonetheless rerun.
Embedded handler remains untouched. Safe identity is child-owned until wait or
explicit ownership loss; no PID kill fallback was added. Exceptional unconfirmed
exit still releases session capacity and reports uncertainty rather than claiming
termination. Simultaneous owner death, trusted interference, arbitrary descendants
and kernel inability to terminate remain outside the guarantee.

The design/PLAN also require **clean-installed lifecycle/packaging evidence and
refreshed affected U10 integration**. Those remain separate owner gates, not
executed or accepted here; therefore this is not a claim that every original U12
release prerequisite is complete. Parent should retain these concrete outstanding
gates. No docs/SPEC15 takeover, requirement weakening, host/shared-runtime change,
restart, push or publication. Passing diagnosis proceeds to verification-owned
acceptance, not an inferred global approval.

## Verify-node final acceptance of independent audit

On unchanged HEAD565a47b, clean worktree and empty diff from565a47b for runtime
and tests, reused immediately preceding same-card evidence above. This reuse is
limited to the identical checkout: relay/matrix/U6 repeats/U8/fault/identity/large
report runs all completed, and no relevant input changed. Newly added independent
EOF policy was rerun during verification. No prior failure is being hidden: the
original pre-fix relay and EOF failures remain in history, with owning fixes and
unchanged reproducer evidence now establishing resolution.

Ran remaining affected checks in one fail-fast sequence with the documented
local Lua environment:

```sh
lua5.4 tests/u6_eof_policy.lua
lua5.4 tests/u6_deadlines_red.lua
lua5.4 tests/u6_ordering.lua
lua5.4 tests/u6_policy.lua
lua5.4 tests/u12_audit_eof_policy.lua
python3 tests/u4_process.py
python3 tests/u5_process.py
python3 tests/u7_process.py
python3 tests/u6_progressive_process.py
python3 docs/check_contracts.py
git diff --check
```

Sequence exit0. Entire partial stdout was read (including final tail):
`work:///cards/card-d-b/processes/proc-c019bd0fa0a3/stdout.log`, stderr at the
same returned process artifact. Six EOF policy branches, before/equal/after
validation-time boundaries,15 ordering permutations, five fatal causes,
completed-timer disarm and independent abandonment checks PASS. U4's15 real-process
groups include independent wait despite descendant-held channel, malformed/partial
frames, descriptor inheritance, blocked startup and bounded fair transport.
U5's28 schema-checked responses preserve result consumption/replacement and
multiworker responsiveness. U7 passes real20MiB configured and16MiB default
values,256-wait saturation, reserved controls, stopped-reader/EPIPE cleanup and
bounded short-write progress. Real TERM-resistant fixture confirmed KILL/reap at
20.011s while1965 other turns progressed. Contracts PASS14 schemas/7 tools/
2 discovery results/23 examples/125 cases. One simulated unconfirmed-exit notice
is expected evidence of truthful abandonment, not a real process failure.

**Final independent audit verdict: ACCEPT checkout implementation and meaningful,
stable affected-suite coverage.** The prior rejection has been repaired at the
owning primitives, not at test expectations. Deterministic clocks resolve timing
boundaries and fake ownership errors without unsafe PIDs; real barriers and external
watchdogs establish actual process ownership, disposal and scheduling behavior.
Five native repetitions address the observed flaky exit race, supplemented by
explicit same/next-turn evidence rather than merely repeated green runs.

This completes this card's independent-review deliverable (explicit verdict and
remaining gaps), not the parent implementation's full release gates. Required
clean-installed executable lifecycle/packaging and refreshed affected U10 evidence
remain outstanding with their separate owners. No such evidence was available or
inferred from checkout tests; parent must not declare full U12/release acceptance
until those gates pass. No additional checkout coverage gap or verified runtime
failure remains in the reviewed original-scope branches. No new product changes,
operator-doc takeover, host change, restart, publication or later-node work.
