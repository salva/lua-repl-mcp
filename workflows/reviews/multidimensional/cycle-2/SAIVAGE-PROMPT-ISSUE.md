# Prompts: counter over-engineering bias with simplicity-first design and safe coarse failure

Publication receipt: user confirmed title/body; created
<https://github.com/salva/saivage-v3/issues/9>. The text below is the published
body, excluding this local receipt. No Saivage source/prompts/deployment changed.

## Summary

Please audit and revise Saivage's shipped agent/workflow prompts so that **simple
architectures and implementations are an explicit design objective**, not merely
shorter code after every suggested robustness mechanism has been accepted.

In the lua-repl-mcp workflow, repeated review/fix cycles tended to preserve and
extend fine-grained recovery, availability and diagnostic guarantees. Subsequent
reviews repaired interactions between those mechanisms instead of first asking
whether the mechanisms or stronger guarantees were necessary. A dedicated
simplicity review produced substantially smaller alternatives.

This is a prompt/design-quality report and improvement request, not a proven
deterministic runtime bug or a claim that all robustness machinery is unnecessary.

## Observed example and evidence limits

The target is [lua-repl-mcp](https://github.com/salva/lua-repl-mcp), a persistent Lua
MCP with an embedded handler and managed worker sessions. Its independent process
ownership, identity checks and bounded cleanup are intentional requirements.

Examples of the distinction we needed the agents to make:

| Complexity pressure | Simpler alternative |
| --- | --- |
| Seamless replacement allocation while a dead allocation awaits release behind blocked bulk, requiring additional retirement/ack/stale-record coordination | Reject replacement temporarily **before accepting/spawning work** until internal capacity is reusable; disposal/control still progress independently |
| Maintaining exact locations for enormous serialization-error keys and selecting a fitting ancestor/path | Omit oversized optional path metadata while preserving completed/possible side effects and the actual failure |
| Fine-grained salvage/recovery after unexpected internal channel/encoding failure | Fail the affected operation/session or connection at a documented boundary, with owned-resource cleanup and truthful outcome uncertainty |
| Adding more handling when review-introduced acknowledgements/validation layers interact | First consider removing the unnecessary mechanism, redundant traversal or stronger guarantee rather than engineering around it |

The workflow included external Astra reviews and host-authored plans as well as
Saivage planners/executors. Therefore this is **not a controlled attribution to a
particular prompt or model**. The deployed instance used dedicated runtime
`39ffe231`, with Astra planning and Sol execution/review; current source may already
contain relevant improvements. Inspect current composed prompts before deciding
what is missing. Existing critical-triage instructions should be retained, not
claimed absent or duplicated into a larger process.

Public context: [fresh minimality review](https://github.com/salva/lua-repl-mcp/blob/a600754a4cfb06983c278f633bd262721588f860/workflows/reviews/project-wide/FRESH_MINIMALITY_REVIEW.md).
Later simplicity review and approved continuation are currently local work records;
do not treat unpushed paths or unpublished conversations as public evidence.

## Take inspiration from Saivage's existing development guidance

These principles are already established for developing Saivage itself:

- [AGENTS.md — Engineering Priorities](https://github.com/salva/saivage-v3/blob/7d1e7170573aec8bc1d25a343da37c0c954d6114/AGENTS.md#engineering-priorities): clean/simple architecture first; minimal justified abstractions; defer nonessential rare-edge-case robustness; prefer owner-local/loss-tolerant operations over unnecessary retries, acknowledgements or registries; accepting a defect does not accept its proposed remedy.
- [AGENTS.md — Runtime Coding Rules](https://github.com/salva/saivage-v3/blob/7d1e7170573aec8bc1d25a343da37c0c954d6114/AGENTS.md#runtime-coding-rules): fail fast at actual consumption; no proactive defensive passes for impossible states or states the system cannot handle safely.
- [AGENTS.md — Testing Priorities](https://github.com/salva/saivage-v3/blob/7d1e7170573aec8bc1d25a343da37c0c954d6114/AGENTS.md#testing-priorities): production architecture should not become complicated for tests; prefer fewer high-value tests rather than broad low-value coverage.
- [Issue-fix adversarial-review skill](https://github.com/salva/saivage-v3/blob/7d1e7170573aec8bc1d25a343da37c0c954d6114/.github/skills/saivage-issue-fix-adversarial-review/SKILL.md): periodically and finally reassess design value/net simplicity, critically triage findings, and consider removing introduced machinery before sustaining it.

Adapt those general principles to generated-project work. Do **not** copy unrelated
Saivage-specific storage, API-compatibility or deployment restrictions into every
target project.

## Requested prompt changes

Audit the effective composition of shared role and workflow prompts in
[`classic`](https://github.com/salva/saivage-v3/tree/master/src/config/system-templates/classic/prompts)
and [`classic-typed`](https://github.com/salva/saivage-v3/tree/master/src/config/system-templates/classic-typed/prompts),
including Planner, Executor, Reviewer, Oversight and design/revision steps where
applicable. Put concise guidance at its actual shared owner instead of repeating
an ever-growing checklist in every leaf prompt.

Suggested behavioral direction, not mandatory wording:

> Prefer the simplest coherent design that meets the user's actual needs. Do not
> equate robustness with detecting, preserving and recovering from every possible
> edge case. For unexpected/rare failures, prefer coarse, explicit, safe failure
> over elaborate recovery unless finer recovery is a concrete requirement.
> Critically evaluate every review finding and its proposed remedy. When new
> machinery causes trouble, consider removing it before adding mechanisms to
> sustain it. Reassess net simplicity throughout revision, including after review
> approval. Ask the owner before adding stronger guarantees or relaxing explicit
> requirements; do not silently turn incidental implementation choices into
> product obligations.

In particular:

1. Separate **safety/correctness** from convenience, availability, precision and
   optional recovery. A rejected operation or lost optional diagnostic can be a
   valid deliberate design, not automatically a defect to fix with more state.
2. Treat findings as evidence, not instructions. Accept, simplify, defer or reject
   with reasons. Require a concrete user impact/requirement; preference-only or
   hypothetical findings should not automatically enlarge scope.
3. Re-derive simple alternatives at real design decisions; consider removing
   features/guarantees or choosing ordinary failure. Existing code, written plans,
   reviewer agreement, historical approvals and sunk cost do not prove necessity.
4. Do not add proactive checks/recovery for states that cannot happen or cannot
   safely be handled. Validate at real trust/consumption boundaries and fail clearly.
5. Keep ordinary bounded fixes ordinary. No extra review roles, persistent
   scorecards, architecture frameworks or exhaustive test campaigns just to enforce
   these guidelines. A coherent refactor can still be the simplest root-cause fix.

## Safety and scope boundaries

“Coarse safe failure” is **not** silent data loss, false success, wrong-request
attribution, automatic replay of uncertain side effects, orphaned processes,
unbounded resource retention, unsafe stale-PID signalling, unauthorized mutation
or secret disclosure. Preserve real ownership/cleanup, authentication and truthful
known/unknown effects. It does not mean crashing on ordinary user mistakes or
turning routine capacity contention into cross-session destruction.

Where a simpler design changes an explicit product guarantee, surface the precise
tradeoff and obtain owner approval. Do not smuggle in either stronger guarantees
or weaker safety under the slogan “simplicity.”

## Acceptance suggestions

- Relevant **rendered** role/workflow prompts consistently express simplicity,
  critical triage and proportionate safe-failure choices without duplicated policy
  or contradictory preserve-every-guarantee wording.
- Representative planning/review examples choose temporary rejection or optional
  metadata omission where sufficient, and still retain mandatory cleanup and
  side-effect truth. Confirm a reviewer can reject an overengineered remedy even
  when its underlying defect is real.
- Follow the existing prompt-authoring/composition validation workflow; focused
  tests protect behavior/composition, not brittle wording or exhaustive edge cases.
- Distinguish shipped-template changes from supported adoption into instance-owned
  prompts. No silent live-instance rewrite, service restart or deployment is part
  of this ticket.

The desired outcome is **less design and implementation complexity**, not another
process layer whose purpose is to manage complexity.
