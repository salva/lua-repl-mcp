# Minimal whole-project repair plan

The operator-requested [multidimensional-review addendum](../multidimensional/PLAN-ADDENDUM.md)
adds narrow local diagnostic, test-oracle and embedding-documentation work within
the same three batches. Critically reconcile its findings with current work;
do not create a parallel repair programme or resurrect superseded machinery.

## Authority and scope

This is the sole current U13 implementation plan. It replaces the expanded
five-batch plan and its prescribed mechanisms; old per-finding analysis/design/
plan editions and review verdicts are historical evidence, not additional work.
F01–F13 remain the issue identifiers, not thirteen independent architecture jobs.

Reconcile against stopped commit `278a522` and preserve current work. The completed
containment changes are not automatically reverted or expanded. Fix demonstrated
bugs and only the supporting machinery needed to establish their correction.
No new product feature, sandbox, compatibility framework, license/release or
shared-runtime change is authorized. User documentation remains primary and
separate from these work records. Saivage executors still must not push/publish,
obtain publication credentials, create deployment workflows or change settings.

Preserve explicit owner requirements: pure-Lua blocking handler in existing host
globals; explicit returns, no automatic capture or public task IDs; independent
guardian OS spawn/reap; approved byte capacities and coupled floors; single-consumer
outcomes and truthful effects; TERM20s then KILL10s, retries1s, original30s total
best-effort disposal. No arbitrary new positional-argument or public path limit.

## Batch 1 — Local correctness and adequate regression gates

Use existing modules/state/helpers. Serialize edits to shared files but do not
invent prerequisite frameworks or force unrelated documentation to wait.

| ID | Required change | Minimum observable regression |
| --- | --- | --- |
| F01 | Fix codec-local locale-sensitive float emission and check parsing without changing host locale | Exact fractional value and return count, object numbers/range, C and available comma locales; preserve locale |
| F04 | Prioritize recorded fatal outcome over an uncommitted expired-wait pending reply | Timeout/fatal orderings and two waiters; already-committed pending replies unchanged |
| F05 | Construct tool/context-correct failures using existing error helpers | Actual invalid-argument/overflow/error outputs validate against each affected advertised tool schema, including metadata where execution exists |
| F06 | Put unpack/call preparation inside protection with marker after preparation and immediately before chunk invocation | Bounded oversized args fail limit_exceeded/execution/not_started, no chunk witness, usable session then success; ordinary runtime errors still started |
| F07 | Explicitly map existing startup/transport/termination causes and observed exit fields | Bad cwd versus stdio, startup EOF/handshake, observed nonzero exit/signal; allowed reasons/stage, bounded diagnostics, original cause survives cleanup |
| F08 | Guard duplicate outstanding IDs before every ID-bearing protocol dispatch using existing request ownership; fix false-versus-decode-error | Duplicate gives -32600/id:null without altering original; false/null/scalar invalid request, malformed JSON parse error; completed-uncommitted IDs stay reserved |
| F09 | Capture optional traceback conditionally and protect its invocation | Import without debug; failing traceback preserves original error; next call works without native imports |
| F11 | Finish only concrete discovery, complete-frame/overall deadline and cleanup gaps | Explicit safe fixture selection; partial frame/perpetual pending bounded; dangerous fixtures remain contained after wrapper/outer timeout |
| F12 | Correct current evidence claims to their actual assertions | Recipe checks are not claimed as ownership/handoff proof; cite applicable current evidence and honest missing coverage |

F06 does not require a new typed-error interface: use the existing public code/
stage/state vocabulary. F07 may add a small shared mapping helper if useful,
not a new typed failure subsystem. F08 reuses manager.requests and its commit
lifecycle: release after successful response enqueue or accepted active-request
cancellation suppression, not evaluation completion. Completed-request cancellation
is inert: no worker kill, response suppression or early reservation release.
Reject duplicates during completed-but-uncommitted delivery as well as running
work; preserve later legitimate reuse and generation checks. Failed enqueue or
disconnect uses existing bounded connection cleanup; never free an ID then let
late execution data answer a new operation.

F11's current external Linux containment helper addresses real outer-wrapper/
escaped-child hazards. Qualify its actual ownership/failure boundary; do not undo
it merely because it came from the previous plan. Conversely, no further manifest
framework or universal migration is required. Pure tests may run independently.
Keep Linux-only harness prerequisites distinct from product POSIX support. Missing
qualification is reported, not silently replaced by an unsafe success claim.

## Batch 2 — Guardian progress, representation fit and outcome ordering

Implement F02/F03/F13 as one coordinated repair, reusing existing transport,
framing, process ownership and manager state. The chosen minimal direction is:

1. Keep independent liveness and add a small separate control socketpair between
   manager/guardian. Reuse existing bounded newline JSON framing for bulk bodies.
   Remove command/report lockstep and full-result snapshot retransmission.
   Ready/error/exit/completion metadata can progress without draining a bulk
   result; input-sized paths/options/diagnostics stay bulk data, not a new small
   control-record restriction. Spawn needs complete validated creation data.
2. Send each execution result once, bound by allocation/generation. Retain it
   until the manager safely takes ownership; a small acknowledgement/discard
   releases the guardian copy. Replacement, consumption and disposal never revive
   stale payloads. Reuse existing identity/state fields rather than a new generic
   event or transfer framework. Bound control queues from admitted work and keep
   disposal capacity available for all live sessions; validate resource arithmetic
   before creating children. No mandatory new queue formula or packet format.
3. Bound aggregate loop work, service control/liveness/timers between worker/frame
   units, and avoid repeated whole-payload encoding/concatenation. Measure the
   largest legal individual record on the actual guardian-backed path. If one
   operation still prevents required control/cleanup progress, make that specific
   path resumable or forward existing encoded bytes; do not waive the failure or
   prebuild a universal incremental codec. Fixed100ms and256-node targets are not
   acceptance requirements. Actual unbounded delay is still a defect.
4. Carry original startup and disposal origins through queues/handoff. Reject
   expired allocations before spawn and implicit dispatch; no late default spawn
   from incomplete creation data. Worker cleanup does not await bulk delivery or
   client response flush. Manager death/disconnect triggers guardian disposal even
   when the result stream is blocked. Preserve original30s fallback, not a fresh
   phase budget on handoff. Signal success alone never proves exit.
5. F03: pass effective byte/depth options through ingress/validation/evaluation/
   wrapping; replace serialize-to-clone with raw structural copying. Use next/
   rawget/rawequal, fresh tables and null/array/object fidelity. Accept valid raw
   data with arbitrary metatables without invoking/copying them; reject invalid
   keys/shapes, cycles, unsafe/nonfinite numbers, malformed UTF-8 and excessive
   depth. No metatable-presence rejection or canonical-wire recheck on admitted
   network input.
6. Preserve the complete already-validated original JSON request as internal JSON
   data, not a quoted/escaped string, with bounded private allocation/generation
   metadata. Its body remains<=I; fixed private overhead fits existing H. Worker
   extracts code/args/creation fields through normal validation into fresh tables;
   it never redispatches the body as another MCP request or obeys its public ID.
   This avoids selected-field source-span machinery and numeric/string expansion.
   In-memory library calls validate/copy and count canonical tool arguments against
   I, retaining that representation for dispatch. Bind immutable request bytes to
   the accepted generation; user mutation cannot replace them after validation.
7. Define nesting units clearly: each user argument/returned value permits D
   nested containers; positional tuples and fixed protocol wrappers are overhead,
   not deductions from D. Root container counts1, scalar leaves add none. Derive
   actual per-envelope allowances from known wrappers, not independent defaults
   or a new universal D+8 contract. Preserve supported configured user depths and
   assert maximum paths through actual worker/public framing.
8. F13: distinguish complete valid worker-result validation (guardian hard-deadline
   evidence), manager complete-payload application (recorded outcome), and public
   response commitment (consumption). Timely validated result defeats a stale
   timeout clock, but incomplete relay alone is not manager completion. Kill or
   accepted active cancellation before manager application can freeze disposal;
   already-recorded results cannot be rewritten. Explicit idle kill still destroys
   the session while preserving bound waiters' result; cancellation of an already
   completed request is inert. Late/stale generations cannot complete new work.

Clarify the underspecified nesting and recorded-completion language in SPEC and
public lifecycle guidance consistently. Do not alter §11.3 completed-cancellation
semantics, owner capacities or safety requirements. No exact private protocol is
an owner requirement; update its description only as actually needed.

Required targeted qualification: deterministic event/deadline permutations plus
real installed guardian CLI with blocked/partial bulk, largest legal records,
concurrent kill/cancel/list, manager-only death and original-deadline handoff.
Test escaped and short-numeric input at tight legal custom worker floors through
one-time real worker execution, effective depths, schema-valid failures and fresh
data. Separately prove admitted session count with small results and zero retained/
consumed payload retransmission. Combined63-near-limit-results stress is optional
unless residual aggregate-size work/scaling evidence makes it necessary. Removing
that ritual does not remove default-capacity support or permit shrinking limits.
No release while measured legal workloads violate bounded cleanup/control.

## Batch 3 — User journey and final integrated qualification

F10: repair source-relative links and the few deterministic staging rewrites;
validate affected README/source/built paths, fragments and schema downloads.
It may proceed independently of process repairs. F12: final claims identify
assertions, tested revision/environment and limits; preserve old evidence as
historical, never fabricate a rerun. Keep all work records out of public artifacts.

Run focused tests for each changed boundary and contract checker/diff checks as
work proceeds. After integrated runtime changes, run one clean installed regression
suite outside checkout and fresh real MCP-client smoke covering the changed paths.
Strict local website build/link/content checks accompany doc changes; repeat
desktop/mobile/browser checks when navigation, layout or relevant behaviour
changes, not for every local runtime fix. Repeat relevant qualification after
regressions or changed inputs; do not replay unrelated campaigns by phase label.
Record exact versions, dependencies, locales and unavailable coverage. Publication
or saved evidence parsing is never proof of current runtime acceptance.

## Delivery and change control

Commit coherent repairs using owner identity, keep red/green evidence proportionate
and serialize overlapping source edits. On regression stop dependent work and make
a scoped corrective commit, not a reset of others' changes. Do not resurrect the
expanded plan through old cards/briefs: root and immediate owning planners must
adopt this current plan before continuing, reconciling existing completed A work.
Re-scope stale descendants through supported lifecycle/record tools; do not reset
history or edit generated state directly. Restart the dedicated service with the
project remaining stopped. Through supported record/lifecycle tools, align
accepted root and immediate-owner directions and re-scope stale executable
descendants before normal Run. Verify agreement with the reviewed revision
before Run, then verify actual returned child tool activity. Do not reset history
or edit generated state.
