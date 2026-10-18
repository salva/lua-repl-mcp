# Approved simplicity-first continuation

The operator approved the [simplicity review](96-SIMPLICITY-REVIEW.md), directed
notification to the main planner and authorized normal resume. This is current
continuation scope, superseding recovery prescriptions in this folder's earlier
99-METAPLAN.md. Preserve completed U1–U13 code/history/evidence; source baseline
`a600754` plus subsequent work-record commits. Planning approval is not runtime
acceptance. Do not repeat old repairs or launch another broad specification review.

## Design rule

**Keep this a simple MCP. Do not overengineer. Critically consider every issue;
prefer the smallest sufficient correction and coarse safe failure to elaborate
edge-case recovery.** Existing requirements are not proof their implementation
mechanism is necessary. Preserve actual process ownership, bounded resources and
best-effort disposal, immutable identities, no wrong-request dispatch/result,
no unsafe remembered-worker-PID fallback, and truthful side effects/completion.
Explicitly document an approved changed guarantee instead of silently contradicting
the public contract. No automatic execution retries.

## Immediate implementation

Use existing main planner/child ownership, serialized edits and coherent local
commits with configured owner identity. Root was DONE before this continuation:
supported accepted-brief adoption/normal lifecycle may mark it CHANGED and create
a new bounded repair goal. That is not a reset or instruction to replay U13.

1. **Lifecycle correctness with simpler admission:** fix stale cancellation of
   resolved busy/create/no_execution operations using existing fields, retaining
   active zero-wait cancellation and accepted-kill cleanup. Keep owned guardian
   finalization/reaping separate from transport closure; bounded/idempotent cleanup
   must handle already-reaped children and report uncertainty honestly.
2. **Temporary capacity rejection, not seamless retirement:** account outstanding
   internal allocations before accepting/spawning replacements. It is approved
   that a publicly dead session's capacity may remain temporarily unavailable
   until existing ordered release progresses. Reject normally before dispatch;
   do not add deferred requests, retirement handshake or unbounded tombstones to
   guarantee immediate replacement under blocked bulk. Disposal/control/liveness
   must still progress independently of bulk. Unexpected internal corruption may
   fail the connection coarsely with owned-worker cleanup; ordinary contention
   must not accidentally destroy unrelated sessions. Document this policy.
3. **Small data repairs:** omit oversized optional error paths with conservative
   encoded-byte allowance; no fitting-ancestor search/general budget subsystem.
   Preserve completed serialization error/effect truth. Fix handler/from_json local
   variable flow and admitted-input propagation through embedded and explicit/
   implicit creation boundaries. Use a small fixed discovery-schema encoding
   allowance independent of validated user depth. No schema-depth engine.
4. **Reduce redundant work only where locally justified:** remove duplicate depth
   traversal if D/D+1 and relevant diagnostic/checkpoint controls prove equivalence.
   Evaluate removing result-ack retention by transferring ownership into existing
   bounded output queue; do it only if simpler and preserves generation/result
   commitment/resource bounds. This is optional, not a prerequisite rewrite.

Coarse failure is approved for unexpected internal/encoding edge cases when it
truthfully preserves completed/possible effects and disposes owned resources.
Never label an operation not_started merely because its result was lost. Public
response commitment/single consumption still matters. Do not delete cooperative
progress at current large capacities if it can stall guardian disposal.

Canonical-only admission, reduced configuration profiles, broad pointer removal,
coarser diagnostic flags and partial-result salvage removal are possible further
simplifications, **not mandatory projects or blanket permission to drop current
default capacities/embedding features**. Prefer the immediate bounded changes above.
If a further reduction is worthwhile, state its precise changed guarantee and
compatibility/effect consequences in maintained contracts and implementation
direction; do not silently inherit or silently weaken guarantees. Escalate genuine
owner conflicts rather than invent compatibility/recovery machinery.

## Focused acceptance and completion

Critically reproduce current claims; close duplicate/already-fixed ones with
evidence. Essential checks: stale-cancel versus active cancellation and single
consumption; observed partial bulk/kill/replacement **rejection** before bulk
restore and later reuse; actual owned-child reap before external harness cleanup;
oversized path failure followed by session recovery; effective admitted bytes and
depth1 discovery/D+1 rejection; schemas and one integrated installed/client pass.
Use existing independent containment for real process ownership; pure deterministic
checks for local rules. Preserve red evidence, exact environments and unavailable
coverage. No exhaustive configuration×population×payload matrix, extra framework,
unbounded review loop or test-count ceremony. Independent implementation review
should challenge complexity as well as correctness and fix concrete residuals.

No provider/auth/model/shared-runtime/host/service changes, generated-state file
edits, reset, publication or push delegated. Resume means supported normal Run,
not service restart. Root and immediate owner must receive current scope through
supported records/directions; verify fresh returned child tools after Run.
