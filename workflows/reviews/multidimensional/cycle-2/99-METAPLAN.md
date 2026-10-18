# Cycle 2 focused repair proposal

## Scope and guardrails

Source baseline `a600754`, already published. This is a proposed correction to
current Lua REPL MCP, not a replacement architecture or authorization to resume
Saivage. The operator says it is paused; API confirmed no runtime/agents/processes.
No fixing agent starts before user confirms this reviewed plan and editing scope.

**Do not overengineer. Critically assess every allegation, not reviewer authority.
Prefer the smallest sufficient correction.** Confirm actual current applicability,
then fix, simplify, defer or reject with reasons. Preserve all owner semantics,
byte capacities, raw trusted embedding, independent spawn/reap, truthful effects,
single consumption and original TERM20/KILL10/retry1/30s policy. No token parser,
new framework, arbitrary quota, stale PID fallback, compatibility project or
unrelated refactor. Preserve user/work separation and candidate status.

The [inventory](00-INDEX.md) merges duplicate handler claims; eight local IDs are
not eight new architecture jobs. Seven concrete groups are proposed for correction
and one cleanup deferred. [Independent skeptical triage](98-SKEPTICAL-TRIAGE.md)
verified all allegations, rejected duplicates and narrowed native-impact claims.

## Batch A — Guardian lifecycle, retirement and observed overlap

Highest-priority [F02](F02-allocation-retirement.md) and
[F03](F03-guardian-finalization.md) share ownership code but require separate
invariants/regressions. Attach [F07](F07-bulk-overlap-oracle.md) evidence correction
to this work rather than create a separate testing programme.

- Make public credit reuse and guardian retirement agree independently of bulk.
  Select minimal independent retirement/ack or proven ordering/deferred replacement;
  preserve immutable allocation identities and original startup origin. Late bulk
  currently assumes known allocations: define safe stale record/ack/dispose handling
  and bounded retained accounting across repeated turnover. Moving release to
  control alone, removing assertions or ignoring dead bookkeeping is insufficient.
  Never regain credit by awaiting bulk drainage.
- Separate failed transport closure from completed owned-child finalization.
  Retain owned guardian PID/identity until reaped, allow idempotent bounded cleanup
  while guardian disposes workers; a single WNOHANG attempt is not enough. Cover
  already-reaped branch and preserve applicable original disposal origin. No false
  confirmed exit, unbounded host wait or stale worker-PID fallback/new supervisor.
- Strengthen existing control fixture with observed partial-result relay, withhold
  reads and require kill/metadata progress before restoration. Partial receipt proves
  overlap, not necessarily kernel backpressure; establish pending/blocked output if
  claiming it. Narrow matrix wording to actual asserted condition and remove old
  lockstep comment. Reuse existing partial-crash/checkpoint techniques.

Targeted contained native qualification: small-capacity full population, actual
partial relay, control disposal/replacement before restoring bulk, unrelated live
session continuity, bounded retirement bookkeeping through repeated turnover,
stale bulk/ack handling and no duplicate result consumption. Long-lived backend
guardian exit/channel failure must show owned identity disappearance/reap before
external harness cleanup, including already-reaped/repeated-shutdown branches.
Deterministic seams complement, not replace process ownership tests. No maximum-
population×size matrix or general watchdog framework.

## Batch B — Local request, data and effective-limit boundaries

Serialize overlapping source edits in codec/contracts/evaluator/protocol/handler,
manager and existing guardian/native creation paths after Batch A. Address
[F01](F01-resolved-cancellation.md),
[F05](F05-admitted-input.md), [F04](F04-error-path-fit.md) and
[F06](F06-discovery-depth.md) as coherent local commits, not one giant refactor.

- First correct resolved operation cancellation using existing fields. Busy/error
  response, completed creation and resolved no_execution wait cancellation must
  not destroy a session's later/other execution. A response existing is not enough:
  active zero-wait execution, active wait, starting creation and accepted-kill
  cleanup must retain their documented cancellation/cleanup behaviours.
- Correct local input dataflow and preserve admitted-wire versus canonical-library
  accounting through embedding and managed creation. Retain structural validation,
  fresh snapshots, immutable admission identity and exact configured capacities.
  Cover explicit and implicit creation paths, not only manager admission. Establish
  admitted context at real ingress, never trust a free caller-supplied bypass flag.
  Remove accidental evaluator helper ambient-global coupling with local dataflow.
  Do not simply patch one variable and leave revalidation failures downstream.
- Keep optional generated error metadata representable at supported floors; omit
  oversized path or choose truthful fitting ancestor without hiding completed
  side effects or original serialization cause. Budget encoded bytes including
  escaping, not just raw path length. Avoid false truncated pointers.
  Retain required diagnostic-loss semantics and original error shapes.
- Derive actual fixed discovery/envelope allowances separately from user depth.
  A valid small user depth must not prevent discovery or weaken user-data limits.

Focused qualification: pure/inert cancellation branches and reservations, plus
memory-handler above-default input/expansion/global
collision/discovery-D1 cases; canonical-library negative controls; creation at tight
custom input bounds for explicit/implicit paths through guardian/native validation;
exact-floor error-frame
encoding and real managed error recovery/side-effect witness; D/D+1 controls and
schema-valid actual outputs. Reuse existing installed/contained fixtures where
possible. No gigantic campaign or changed limit to avoid a red boundary.

## Final integrated handback — no extra product batch

[F08](F08-redundant-depth-walk.md) is optional/deferred. Remove only if equivalence
and relevant checkpoint/error behaviour are proved locally; not a release blocker
without a correctness/performance failure. Prefer leaving harmless extra work to
introducing late risk during functional corrections.

Use schema checker/diff checks and relevant existing regressions per commit. After
runtime integration, run one current clean installed suite and fresh real-client
calls for affected paths; preserve actual returned results and exact environment.
Do not call a parsed historical transcript a fresh run. Site need not be rebuilt
for runtime-only changes; if user-facing contracts/docs change, strict local
allowlist/build checks suffice unless navigation/behaviour needs browser retest.
No unrequested publication, GitHub settings, provider/runtime config or lifecycle
operation is delegated to subagents.

## Verification, correction and recovery

One Sol fixing agent, serialized overlapping changes, coherent owner-identity
commits with local IDs in messages and no unrelated staging. Fresh independent
Astra verifies changed boundaries, concrete regressions, historical baggage and
review-induced complexity; Sol corrects substantive residuals. At most3 rounds,
earlier scoped approval ends loop. Repeated same objections twice, owner-contract
conflict or unqualified containment escalates instead of speculative machinery.

Stop dependent work on regression, preserve red receipts and actual effects, fix
with scoped forward commits. Never discard others' work, reset generated state
or silently roll back a runtime with effects. If undoing an agent-owned commit is
necessary, assess dependencies and use a narrow corrective/revert commit only
within task authority; user/runtime state is never restored as code rollback.
Final handback distinguishes fixes, deferred cleanup, unavailable tests and
remaining requirements. No absolute absence-of-defects or release claim.
