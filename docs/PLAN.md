# Implementation plan

## Authority, scope, and execution policy

Implement `docs/SPEC.md`, using `docs/schemas/api.json` and the normative wire
examples in `docs/MCP_EXAMPLES.md`. `docs/check_contracts.py` checks documentation
contracts; it is not evidence that a server exists or works. The specification,
including section 14's settled defaults and ordering rules, remains authoritative.
This plan neither changes that contract nor implements runtime code.

Independent review of this plan against all four source documents approved
revision `fa2e96b` with no required corrections; see `workflows/REVIEW.md` for
the receipt. Launch is an operator/owning-session action. Implement the
dependency-ordered units below, committing
working increments with their evidence. Do not turn the project into repeated
design reviews: each unit ends in executable behavior and focused validation.
Escalate an actual dependency blocker or contract contradiction with reproducing
evidence; do not silently relax requirements or reopen settled API choices.

Dependencies and platform capabilities have not been verified by this planning
work. In particular, no luaposix release, JSON codec, newer Lua release, or host
adapter is claimed compatible yet. Record exact versions and commands when tested.

## Architecture and dependency order

Keep pure-Lua data validation, JSON conversion, evaluation, framing, and the
blocking handler independent of manager/native imports. The public modules live
under `lua_repl_mcp`; `lua_repl_mcp.handler.serve(io_adapter, options)` and
`require('lua_repl_mcp').null` have their specified interfaces. Evaluation uses
the existing interpreter's globals. Manager modules own POSIX resources, process
supervision, admission, timers, and connection-scoped sessions. Workers reuse the
evaluator/handler implementation through a private versioned protocol, rather than
creating a second public MCP connection.

| Unit | Prerequisites | Deliverable |
| --- | --- | --- |
| U1 | Approved plan | Pure-Lua contracts, strict codec boundary, evaluator |
| U2 | U1 | Blocking handler, adapter framing, lifecycle handoff |
| U3 | U2 | Runnable POSIX/luaposix capability spike and pinned dependency |
| U4 | U1–U3 | Worker transport, supervised startup and stream setup |
| U5 | U4 | Manager state machine, execution/wait/list semantics |
| U6 | U5 | Deadlines, kill, cancellation, failure and shutdown cleanup |
| U7 | U6 | Resource limits, admission fairness and payload budgeting |
| U8 | U2, U7 | Complete manager MCP integration and live conformance |
| U9 | U8 | Packaging, real embedding integration and release acceptance |
| U10 | U9 | Real Saivage MCP-client integration and defect reporting |
| U11 | U9; U10 for integration-status content | GitHub Pages-compatible documentation content and local validation |

Test seams are internal: injectable monotonic clock, poll/process operations and
response-commit boundary, plus controllable process fixtures. They must not add
public task IDs, queues, reset tools, detached sessions, or alternate semantics.

## U1 — Pure-Lua contract and evaluator

Implement runtime argument validation and defaults for all seven tools, strict
JSON conversion, stable null sentinel, result/error constructors, and evaluator.
Select a pure-Lua codec only after testing its token-level number and Unicode
behavior; adapt or implement strict lexical validation where necessary. Schema
validation alone cannot establish numeric precision or apply defaults.

Compile complete chunks once, without expression fallback or source rewriting,
then execute a protected call in the existing global environment. Preserve explicit
return count and positional nulls. Format arbitrary thrown values safely, without
depending on user metamethods. Errors preserve side effects and session usability.
Serialize raw table entries under the exact array/object/empty-table mapping;
reject the entire payload on unsupported values, cycles, holes, mixed keys,
invalid UTF-8, depth/size overflow, or prohibited numbers. Use RFC 6901 pointers.
Implement diagnostic byte escaping and combined message/traceback truncation with
the required flags and notice. Never override print/io functions or capture output.

**Acceptance/evidence:** pure-Lua tests on Lua 5.4 with manager/native modules
unavailable; persistent globals/functions versus nonpersistent chunk locals;
zero returns, trailing/intervening nils, nested sentinel values, fresh argument
tables, empty arrays returning objects, recoverable syntax/runtime/serialization
errors, and side-effect counters proving no second execution. Test functions,
userdata, threads, cycles, holes, hostile metamethods and invalid bytes. Test both
safe integer boundaries and adjacent out-of-range values in integer, decimal and
exponent JSON spellings, including tokens that binary conversion would round;
Lua integer/float outputs, nonintegral rounding, overflow and non-finite values.
Verify pointer escaping for slash/tilde keys and absence of partial values.

## U2 — Blocking handler and parent-owned adapter

Implement newline framing separately from stream operations, and the direct MCP
surface (`repl_execute`, `repl_close`) using the same protocol core later used by
the manager. Implement initialization/version negotiation, initialized, ping,
discovery, tool calls and protocol/tool error separation for the direct surface.
Enforce the exact plain-function read/write/flush adapter signatures, including
partial I/O, EOF, write progress and error handling. The handler runs on its
invoking thread and does not service requests while evaluation is active.

On close, stop execution admission, write and flush the acknowledgement if
possible, then return the specified lifecycle record. Preserve raw complete
trailing frames in arrival order and the incomplete tail without decoding or
executing them. Leave unread adapter-owned bytes there. Never close/shutdown
handles, reset globals, or exit the host, on any return path.

**Acceptance/evidence:** scripted byte-stream adapters split every frame boundary,
combine multiple frames, perform short writes and fail reads/writes/flushes.
Assert `acknowledgement_sent` only after successful flush, close request context,
all lifecycle reasons and no calls to parent cleanup. Feed close followed by
complete and partial execute frames in one read; replay the handoff plus remaining
adapter bytes through parent code and prove no loss, duplication or early effects.
An in-process host fixture exposes an API/global, observes mutations, continues
after serve returns, and separately demonstrates parent-selected reset/shutdown.
Verify direct schemas reject manager-only fields and do not advertise deadlines
or destructive managed cancellation. A blocked execution cannot process close.

## U3 — POSIX capability spike

Build a small executable capability test before committing the manager to binding
assumptions. Verify a specific luaposix release with Lua 5.4 for process creation
and exec, pipes or socket pairs, descriptor duplication, nonblocking reads/writes,
close-on-exec, polling, monotonic time, signals and nonblocking child reaping.
Exercise interrupted calls, partial I/O, EAGAIN, SIGPIPE/EPIPE, exec failure and
descriptor cleanup. Check the intended interpreter/module search path after exec.
Pin the demonstrated compatible release in packaging when packaging is introduced.

**Acceptance/evidence:** exact dependency/interpreter/OS versions, reproducible
spike command and results showing a blocked child never blocks the parent, forced
termination and confirmed reaping, and no leaked pipe ends. Identify extensions
explicitly; Linux-only facilities must not become an undocumented POSIX baseline.
If required bindings are absent, report the specific capability and a bounded
implementation remedy consistent with luaposix; do not claim portability from
API names alone. Keep the handler usable without installing luaposix.

## U4 — Worker transport and supervised startup

Implement bounded private newline frames with protocol_version 1, allocation
generations, file_created/ready/startup_error records, and generation-tagged
execute/result messages. Dedicated descriptors must survive intended worker
startup, remain separate from FDs 0/1/2, and not leak into subsequent child execs.
Monitor process exit independently of transport EOF. Use nonblocking manager I/O
and bounded writes/drains. Unknown, stale, duplicate or malformed replies cannot
complete another execution; dispose of corrupt workers.

Perform cwd resolution and potentially blocking stream opens in the supervised
worker. Implement exclusive 0600 output creation subject to umask, one shared
destination for identical stdout/stderr paths, existing-file stdin and device-open
/dev/null defaults. Keep streams across executions. Report each created file
before another blocking setup step; retain created files on failure, report only
known paths and honest completeness. No user code runs before valid readiness.
Startup begins at allocation, uses the 30-second default and validated finite
configuration, and remains separate from execution/wait timers. Late readiness
after abort cannot resurrect allocation. Reuse bounded cleanup developed in U6;
until then test startup failure with the spike's confirmed-reap path.

**Acceptance/evidence:** real worker fixtures for ready, exec/cwd/open failure,
invalid handshake, partial frames and delayed readiness. Block a child on FIFO
open while another worker stays usable; verify startup timeout and partial file
records, including death between creation and reporting. Test relative cwd/paths,
existing files unchanged, shared output, permissions, retained failure artifacts,
stdin reads, native/subprocess output separation and no control-channel inheritance
preventing exit detection. Standard worker parent exits after handler return.

## U5 — Manager state machine and single-consumer results

Implement connection-owned sessions with never-reused opaque IDs and live states
starting/idle/running/terminating. Keep execution status separate. Explicit and
implicit creation share allocation; validate all arguments before allocation.
Dispatch atomically reserves idle state, replaces the preceding retained result,
assigns a generation and arms applicable deadlines before bounded command writes.
Reject busy/terminating execution without altering state or prior results.

Implement null/zero/positive/default waits, dispatch-relative execute waits and
acceptance-relative explicit waits. Zero execute returns pending acceptance even
if completion is imminent. Bind each waiter to its original generation. Retain
live terminal success/errors without TTL until replacement or consumption; consume
only when a budget-checked terminal reply is committed for transmission. One
waiter receives the payload; other waiters receive result_unavailable with its
terminal status. Listing observes but never consumes. No-execution, unknown-session
and consumed-result cases remain distinct.

**Acceptance/evidence:** deterministic clock/commit tests and real two-worker
tests show a busy worker cannot stall other sessions. Exercise all wait modes,
implicit allocation and errors with actual IDs, pending-to-poll completion,
retained errors, rejected execution preserving results, two successful/failed
waiters, replacement with old waiters outstanding, and response commitment before
disconnect. Assert code executes exactly once and list snapshots include starting,
idle, running, terminating and result availability without introducing history.

## U6 — Deadlines, kill, cancellation and cleanup

Implement monotonic hard deadlines and authoritative outcome recording. Completion
requires a complete valid response received before the deadline. On exit/EOF,
drain only currently available bounded bytes before classifying failure; an already
available complete response can win over observed exit. Reached hard deadlines or
accepted kills of active execution freeze their outcomes. Disarm completed timers.

Implement synchronous-to-caller kill with nonblocking forced termination/reaping
and the specified 30-second fallback. Bind cleanup to the selected worker. Resolve
fatal waiters after cleanup with confirmed-exit information; preserve original
timeout/kill/failure causes. Never rewrite completed results. At cleanup completion,
remove all session data; keep only minimal OS reaping bookkeeping if necessary.

Map cancellation by outstanding JSON-RPC request ID: execute/wait kills its bound
session; creation aborts without dispatch; accepted kill continues cleanup; list
has no destructive effect. Suppress cancelled-request replies as specified while
resolving other waiters. Ignore unknown/completed/answered IDs. EOF, output failure
and shutdown stop admission and dispose of all owned starting/idle/running workers.

**Acceptance/evidence:** table-driven event permutations cover complete-result vs
exit/EOF, exact-deadline/late/partial completion, kill vs completion/response commit,
stale timers and generations, cancellation before/after pending response, and late
ready after abort. Inject an unreapable process model to reach the fallback without
depending on an actual unkillable process; assert successful kill, false exit flag,
notice, slot release, no session history and original failure causes for other
cleanup paths. Real fixtures run an infinite Lua loop, blocked native/OS call,
os.exit, unexpected signal and live-worker transport closure; verify independent
session responsiveness and actual reaping. Disconnect during allocation, execution
and short response writes. Explain side effects, descendant and cleanup limits
without claiming EOF identifies a crash cause.

## U7 — Bounds, fairness and worst-case encoding

Implement and validate all section 14.4 defaults together: 64 sessions including
starting/terminating, 16 MiB input and serialized values, 64 KiB diagnostics,
depth 128, 256 ordinary requests, 32 control slots (at least 8 kill-only), 64 MiB
worker frames, 128 MiB complete responses and 256 MiB buffered client output.
Apply SPEC section 14.4's conservative budget floors to defaults and overrides
uniformly. Remove any default-fit exception or unresolved-fit flag from the
implementation. Preserve the historical 64 MiB counterexample as regression
evidence, and add a green default-bound check using the updated production
configuration, maximum legal request ID, and escape-heavy values. An old
hardcoded 64 MiB bound is not the current acceptance target.
Preserve the specified timeout defaults/ranges. Cancellation notifications require
no request slot. Read fairly at admission capacity, reject excess work without
dispatch, bound control floods, and service timers despite sustained traffic.

Budget encoded bytes, not raw strings: include JSON escaping, structuredContent,
its re-escaped compatibility text, JSON-RPC IDs/envelope and notices. Demonstrate
the worst-case bound mathematically and with generated payloads for each supported
configuration, including the maximum legal request-ID overhead. Validate coupled
limits so a legal maximum result fits worker/public/output transport budgets where
applicable; do not apply the smaller public input limit to worker results.
Reject an oversized incoming frame before storing its entire length. Value-bound
failure is result_serialization_error; a complete-response overflow becomes a
small limit_exceeded reply with no partial frame. Budget before result consumption.
Bound output/backpressure and disconnect with cleanup if bounds cannot be kept.

**Acceptance/evidence:** boundary tests just below/at/above every limit, encoded
control-character/backslash/quote-heavy values near 16 MiB, maximum-depth values,
large IDs and diagnostic expansion, duplicated text equality, and incompatible
operator configurations. Saturate ordinary slots with waits, then prove kill,
list, ping and cancellation remain serviced; saturate other control slots and
prove kill reservation. Slow/stopped client readers and fragmented workers must
not cause unbounded buffers, partial JSON frames or timer starvation. A legal
maximum result must not disconnect unrelated sessions. Record measured buffer
high-water marks against explicit bounds, not an unsupported constant-RSS claim.

## U8 — MCP integration and live protocol conformance

Wire the complete manager into its stdio executable using the protocol core from
U2. Advertise only the five manager tools or two direct tools, with independent
root-object input/output schemas expanded from the authoritative definitions.
Apply runtime defaults and unknown-field checks. Implement MCP 2025-11-25
negotiation/lifecycle and request correlation, including out-of-order responses;
advertise tools only, not MCP Tasks. Supply the section 14.7 discovery semantics
and appropriate direct-host instructions. Emit protocol-only stdout.

**Acceptance/evidence:** an external stdio client performs initialization, ping,
discovery, explicit/implicit allocation, concurrent execution, wait, cancellation,
kill and disconnect against actual processes. Validate live tools/list and results
against the pinned official MCP schema and all fourteen standalone schemas; verify
isError exactly matches error presence and decoded text equals structuredContent.
Replay normative example scenarios with generated IDs and semantic assertions.
Exercise pre-initialization calls, malformed requests, unknown methods/tools,
notifications, invalid arguments and short input/output chunks. Run the direct
handler over a real supplied dedicated channel and repeat close/handoff checks.
Run `python3 docs/check_contracts.py` with jsonschema==4.19.2 (or its documented
digest-checked offline schema path); do not substitute that check for live tests.

## U9 — Packaging, embedding validation and acceptance delivery

Provide LuaRocks packaging and `lua-repl-mcp`, with the verified luaposix pin and
strict pure-Lua codec dependency strategy. Installation must expose all required
modules and worker entry paths without source-tree-relative assumptions. Document
how an embedded host loads only the pure-Lua handler without manager/native imports.
Ship setup, configuration, adapter, trust, output and lifecycle guidance consistent
with the contract; document actual tested versions and POSIX extensions.

**Acceptance/evidence:** install into an empty LuaRocks tree and run from outside
the checkout with no inherited development LUA_PATH/LUA_CPATH. Verify module loads,
CLI discovery, child exec/module resolution and the external stdio suite. Run the
core/handler and manager suites on Lua 5.4 and newer stable PUC-Rio versions
available at validation time; report exact versions, failures and unavailable
targets rather than claiming future compatibility. Native dependency limitations
must be explicit, and must not contaminate pure-Lua handler support.

Validate a dedicated adapter against an actual host-owned Lua 5.4+ interpreter
and its embedding/handle API, documenting that API and host thread identity. A
small test host is acceptable evidence for that host only. Demonstrate host API
calls, live global mutation, no second runtime or module-created threads, close
acknowledgement before parent cleanup, intact handles/state and continuation of
complete/partial trailing messages. Scripted adapters alone do not establish this
integration. Run the full acceptance matrix below and publish commands, versions,
pass/fail outcomes and any concrete unresolved blockers. Completion means all
required criteria pass; reviews or documentation alone do not complete the project.

## U10 — Try the completed MCP server with Saivage

Once the MCP implementation and clean-installed package are ready, configure it
as an actual stdio MCP server in Saivage using supported configuration and MCP
server controls. Exercise it through a real Saivage agent, not just the standalone
conformance client. Use isolated integration sessions and bounded workloads.
Keep the development instance's active work and credentials intact; use an
isolated Saivage test project when client lifecycle/cancellation tests would
interfere with the running implementation workflow.

Cover server launch and initialization, tool discovery and usable schemas,
explicit and implicit session creation, persistent globals and functions,
JSON arguments/results, synchronous execution, async execution and wait,
single-consumer results, recoverable errors, list, kill, and client disconnect
cleanup. Exercise finite wait expiry and hard execution timeout independently,
and determine how Saivage's own request deadline/cancellation affects the session.
Verify the agent actually receives and interprets pending, terminal, and tool-error
results. Retain returned tool-call evidence, not merely configuration screenshots
or a connected-server indicator. Confirm unrelated sessions remain usable.

**Acceptance/evidence:** write `docs/validation/SAIVAGE_INTEGRATION.md` with the
MCP package revision, Saivage release/revision, Lua/dependency versions, sanitized
server configuration, reproduction commands/agent instructions, scenario matrix,
actual responses, pass/fail/blocked outcomes, and cleanup results. Use exact
versions and make clear which scenarios were actually run.

Saivage may contain MCP-client defects. For each suspected Saivage-side failure,
write a report under `docs/reports/saivage/` containing expected versus observed
behaviour, minimal reproduction, relevant sanitized protocol/tool evidence,
frequency, impact, and the Saivage revision. Compare with the independent stdio
client when possible to distinguish a server defect from a client defect; label
uncertain attribution explicitly. Link each report from the integration matrix.
Never include credentials or unrelated private conversation content.

Fix defects in this project's server and rerun affected scenarios. Do not patch
the shared Saivage deployment, relax the public contract to hide client bugs, or
claim a blocked scenario passed. External bug reports are a valid documented
outcome for affected U10 scenarios; complete other independent scenarios and
report the remaining integration limitation. Filing public upstream issues or
modifying Saivage itself requires separate operator direction. A concrete report
is required even when no upstream fix can be made during this project.

## U11 — GitHub Pages documentation website

Implement `docs/WEBSITE_DESIGN.md` after the package/API are stable. Create
task-oriented guides, an accessible responsive MkDocs site, deterministic
allowlisted reference staging and pinned local build dependencies. Do not create
publishing workflows. Keep normative requirements/schemas authoritative rather
than maintaining divergent copies. Link the public Saivage limitation report
where useful without exposing raw agent transcripts or deployment credentials.

Build and test locally. Verify project-prefix links/assets, relevant
examples against runtime/contracts, desktop/mobile navigation, and artifact
exclusions. Record reproducible evidence in `docs/validation/WEBSITE.md`.
This documentation stage does not change manager/handler semantics or reopen
completed implementation stages. It may progress independently of an externally
blocked Saivage scenario using honest status text.

Scope is content creation and local validation only. Saivage lacks publication
permissions: do not seek them, create deployment workflows, push, publish, alter
repository Pages settings, or trigger deployment. Completion means authored
content/assets and the verified local site artifact. Publication is outside this
task, not a blocked acceptance gate.

## Test orchestration and evidence rules

- Pure tests use deterministic clocks, process-operation fakes and response-commit
  barriers, with explicit event permutations rather than timing-sensitive sleeps.
- Process fixtures use readiness/control barriers and external watchdogs. They
  cover blocked opens/calls, partial frames, early exits and inherited descriptors;
  always clean up fixture processes and files, even on assertion failure. Test
  timeouts must fail boundedly rather than leave autonomous runs hanging.
- Keep fixture expectations independent of implementation outputs. Assert public
  effects, responses, process ownership/reaping and resource bounds, not only
  private helper return values. Simulations establish rare race/fallback ordering;
  real process tests establish actual OS integration. Neither replaces the other.
- Record reproducible commands and versions with each unit's evidence. Missing
  dependencies are reported as blocked validation, never passing tests. Use the
  pinned upstream schema digest and documented offline mode for reproducibility.
- Run focused checks per increment, then the complete clean-install suite at U9.
  Run real Saivage integration and defect reporting at U10. Fix demonstrated
  project defects and regressions; avoid redundant review-only stages.

## Specification acceptance traceability

Every row must link to concrete test names/results in the implementation evidence.
The mapping below is a work allocation, not a claim that tests currently exist.

| SPEC §8 criterion | Units | Required observable evidence |
| --- | --- | --- |
| 1 | U1, U8 | Globals/functions persist across calls |
| 2 | U1, U8 | Return count/nils and explicit client capture |
| 3 | U1, U8 | Syntax/runtime errors followed by successful execution |
| 4 | U2, U9 | Real host globals and API mutation without manager |
| 5 | U2, U9 | Structured return reason, live interpreter |
| 6 | U2, U9 | Parent-selected reset/shutdown after return |
| 7 | U4–U6 | Separate states, cleanup, fresh never-reused IDs |
| 8 | U2, U9 | Invoking host thread; no module-created threads |
| 9 | U5, U8–U9 | Long execution completion and accurate timeout guidance |
| 10 | U4, U8 | Native/Lua/subprocess output never enters protocol stdout |
| 11 | U5, U8 | Concurrent workers, one connection, correct RPC correlation |
| 12 | U6, U8 | os.exit kills worker only and resolves waiters |
| 13 | U6 | Hard deadline cleanup, other session usable, stale timer inert |
| 14 | U5, U8 | All waiting modes and one-time execution |
| 15 | U5, U8 | Immediate pending and completion-to-poll retention |
| 16 | U5–U6 | Exactly one result consumer, including direct execute reply |
| 17 | U6 | New/idle/running kill, repeated unknown ID, worker-bound cleanup |
| 18 | U4–U5, U8 | Null execution allocates; wait/kill null rejected |
| 19 | U5, U8 | Responsive non-consuming list and empty list |
| 20 | U1, U8 | Nested/positional null conversion through varargs |
| 21 | U4, U6 | Recoverable errors versus fatal exit/transport loss |
| 22 | U2, U4, U9 | Direct close/ack/handoff and standard wrapper exit |
| 23 | U2, U9 | Ordered raw complete/partial trailing-frame handoff |
| 24 | U1, U8 | Lexical numeric boundaries and Lua subtype equivalence |

| SPEC §14.8 completion check | Units | Required observable evidence |
| --- | --- | --- |
| 1 | U4, U6 | Blocked startup open, partial creation records, responsiveness |
| 2 | U6 | Result-before-exit and deadline/kill race permutations |
| 3 | U5–U6 | Two waiters, success/error, single consumer |
| 4 | U7–U8 | Saturated ordinary slots with working kill/cancellation |
| 5 | U7–U8 | Worst-case escaping/duplication at legal limits |
| 6 | U1, U8 | Pointers, side effects, no partial payload/metamethod calls |
| 7 | U6, U8 | Disconnect at startup/execution/transmission, bounded disposal |
| 8 | U6 | Simulated unconfirmed exit, truthful successful kill, removal |
| 9 | U4 | Exclusive files, relative cwd and shared destination |
| 10 | U1, U4, U9 | Unmodified output functions, explicit capture only |
