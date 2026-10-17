# Project repair metaplan

## Scope and fixed design

Reconcile current source with baseline `8383c03e1d1b38fb33a0573f80aeecdf179673ee`
before implementation. Preserve owner mandates: pure-Lua blocking embedding in
host globals, explicit return/no capture/public task IDs, independent guardian
spawn/reap, existing public capacities, single-consumption and TERM20/KILL10 at1s
then abandonment after30s. No shared-runtime edits or generalized sandbox.
Publication is excluded from repair acceptance: the operator separately authorized
and performed host-owned repository/Pages publication; autonomous executors
remain no-publish. The public site is a development candidate, not release proof.

Use the selected priority-control/bulk/liveness topology in F02 and the selected
three-boundary manager-authority model in F13. Neither choice is deferred to an
executor. User-data depth, tuple/envelope headroom, original network-byte versus
canonical library-input accounting, failure shapes and request-ID commitment
rules are defined in the linked designs. Implement those contracts coherently,
not a mixture of old snapshots and new controls.

## Ordered batches and work packages

| Batch | Selected work packages | Importance / transversality | Acceptance |
| --- | --- | --- | --- |
| A: trustworthy gates | [F11](F11-test-containment/03-plan-r2.md), initial [F12](F12-evidence-claims/03-plan-r1.md) claims | 4/4, 2/2 | Explicit fixture manifest, external containment owner survives nested/aggregate crashes, complete-frame and total-scenario timeouts |
| B: shared data/errors | [F01](F01-locale-numbers/03-plan-r1.md) then [F03](F03-limit-context/03-plan-r3.md) jointly with [F05](F05-error-shapes/03-plan-r1.md); [F07](F07-failure-provenance/03-plan-r2.md) mapping interface | 5/4, 5/5, 4/4, 4/4 | Locale-safe values/counts, effective depth/byte context, valid raw metatable-bearing copies, immutable selected-field spans fitting tight worker floors, schema-valid errors and mapping before C |
| C: invocation/ingress | [F06](F06-invocation-boundary/03-plan-r2.md), [F09](F09-optional-traceback/03-plan-r1.md), [F08](F08-ingress-robustness/03-plan-r2.md) | 4/3, 3/2, 4/3 | Exact pre-entry error state, optional/failing traceback, single ID-reservation registry with explicit duplicate policy and enqueue/suppression release |
| D: lifecycle transport | [F13](F13-completion-arbitration/03-plan-r3.md) plus [F02](F02-guardian-control/03-plan-r3.md), [F04](F04-fatal-wait/03-plan-r1.md), [F07](F07-failure-provenance/03-plan-r2.md) native propagation | 4/5, 5/5, 4/3, 4/4 | Original deadlines, serial bounded bulk plus independent control, large creation/path bodies, configured disposal reserves, inert completed cancellation, truthful outcomes and installed aggregate-load proof |
| E: user journeys/evidence | [F10](F10-source-links/03-plan-r1.md), final [F12](F12-evidence-claims/03-plan-r1.md) | 3/3, 2/2 | Repository and built journeys work; claims linked to current executable assertions; final installed/live-client acceptance |

F13 design is fixed before C; implement its normative text with D and test C's
reservation rules against that same contract. Batch B's F07 interface satisfies
C's dependency; D only adds native/guardian propagation. F01 precedes F03 and
F03/F05 are integrated before C/D. Serialize overlapping codec/manager/transport
edits; keep D a coordinated ownership batch, not competing per-issue executors.
No new owner decision or extra review campaign is an ordinary implementation gate.

F02 uses serial FIFO transfers, not interleaved parser states; input-sized
creation/path metadata goes in referenced bulk bodies, with full options and
original-deadline check before spawn. Control queue/byte capacity is derived and
validated against configurable admission before any resources. F03 preserves
only validated code/args/options raw source spans to avoid internal re-encoding
expansion under unchanged coupled floors. F13 explicitly separates idle explicit
kill from inert cancellation after manager completion; the latter keeps its
normal response/reservation until commitment. These shared rules govern B/C/D.

## Required qualification

Each batch retains minimal red evidence then green assertions, contract checker
and diff checks. Use exact supported Lua/native/browser/locale versions; missing
dependencies mean blocked qualification, not automatically a product defect.
Use actual protocol ingress and corrected installed runner outside checkout.

D must exercise the installed guardian-backed CLI with legal default aggregate
results (up to63 retained near-limit results plus another active session), retained
versus consumed payloads, kill/cancel/list, original queued-startup deadlines,
noncompleting bulk, control overtaking partial payload and original disposal
handoff. Measure healthy100ms control-service target and30s total disposal with
recorded scheduler allowance; do not assert impossible OS real-time guarantees or
let tolerance reset deadlines. Scaled deterministic tests supplement, not replace,
the default-capacity process case. Old U7 native-supervisor fairness tests do not
certify this transport. Prove event outcomes from F13's table and fallback shapes.

At D/E completion run full current process/lifecycle/cancellation/resource and
clean-install gates, fresh actual-client returned tool evidence and source/built
documentation checks. A saved-evidence parser is not a live trial. Strict site
builds, prefix assets/downloads and desktop/mobile/keyboard smoke stay local;
publication is never delegated to the autonomous process or used as acceptance.

## Delivery, recovery and simplification

Commit coherent batches with owner identity, current evidence and changed-input
applicability. On regression stop dependent work and correct/revert only the batch
in a reviewed new commit, preserving red evidence; no destructive reset of others'
work, force push, license change or new public release is implied.

Remove accidental hidden defaults, full snapshot retransmission, loose fixture
discovery and incomplete duplicated watchdogs. Keep necessary result identity,
strict conversion, ownership and partial-effect honesty. Do not add compatibility
paths or generic frameworks to preserve accidental design history.

## Planner handoff

Root must adopt accepted tasks/brief and reconcile any already-fixed findings,
including operator publication changes since the baseline. Update stale public
source-link acceptance without replaying completed work. Resume with supported
Run if stopped; otherwise preserve running work. Verify accepted record locators
and actual child tool activity, not just queued notifications or running status.
