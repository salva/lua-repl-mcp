# Consolidated Astra review report

## Outcome

Four read-only reviewers found **three narrow new findings and one residual
existing test defect**, not grounds for redesign. Most runtime observations
duplicate the active minimal U13 plan. Complete that work rather than launching
a competing repair programme or resurrecting superseded machinery.

### Proposed small additions

1. Avoid retaining whole expanded diagnostics before clipping (medium).
2. Require worker reaping, not merely termination, in one manager-crash oracle
   (medium; no demonstrated product zombie leak).
3. Document the existing embedded evaluator option names (low).
4. Check time after the final frame read (low; already within F11).

See [critical inventory](00-INDEX.md) and its per-issue evidence. The orchestrator
independently inspected all four claims and reproduced the frame deadline
false-positive with a fake clock. Diagnostic operational impact needs measurement;
the review does not establish memory exhaustion, real-time latency or a sandbox
guarantee. No source/build/process acceptance suite was run by reviewers.

## Critical filter

Accept findings only for source-demonstrated failure or meaningful missing user
information. Existing U13 defects remain with their owners. Corrected F12 claims
are not reopened. Assertions of product reap failure, broken published pages or
measured performance would exceed this evidence and are rejected. Proposed
solutions are narrowed to existing modules/helpers and one relevant oracle.
Each finding compares a focused correction with a proportionate alternative;
none justifies a general framework. Scope remains pinned `701320b` until compared
with active source at a safe implementation handoff.

## Implementation proposal — NOT authorized to run yet

User selected review-only while Saivage continues. No fixing agent has started,
no project execution/service was stopped, and no source/tests were changed by
this review. Once user confirms Saivage is paused/finished and approves this
proposal, one Sol fixing agent can handle nonoverlapping coherent commits:

1. Reconcile all four items against current source, accepted U13 tasks and work
   in progress. Drop already-fixed/unsupported allegations with reasons.
2. Frame oracle and crash-reap oracle: pure timing regression first, then narrow
   contained ownership mutation/installed case. Keep harness cleanup independent.
3. Diagnostic helper: bounded retained output and preserved flags, targeted
   correctness/allocation evidence; do not impose new public execution limits.
4. Existing options docs: compact example/table and relevant guide/option check.

Order may follow existing task ownership and touched-file dependencies. Existing
final installed qualification can include these runtime changes; do not demand
another full campaign for every edit. Use schema checker and diff checks where
relevant, coherent owner-identity commits, no reset/push/publication/state edits.

**Mandatory fixing-agent direction:** Do not overengineer. Critically assess every
reported issue rather than assuming the reviewer is right. Prefer the smallest
sufficient correction. Reject/defer unsupported, duplicate or already-fixed work
with evidence. No broader refactor/new framework without concrete necessity.
Preserve owner semantics, truthful effects and actual cleanup guarantees.

After fixes, fresh Astra verifies actual changed boundaries and findings, including
historical baggage and review-induced complexity; Sol corrects concrete residuals.
Cap at three correction rounds, stopping earlier on scoped approval. Repeated
unchanged objections or an owner-requirement conflict require user decision, not
unbounded iteration. Never label unavailable tests as passes.

## Strengths and limits

Pure embedding/native separation, guardian creation ownership, generation/commit
boundaries, capacity arithmetic, substantive containment and installed identity
checks, user/work separation and honest portability claims are worth retaining.
Sunk cost and prior approval are not proof, but neither is size a reason to remove
correctness machinery. The current minimal plan is the right implementation scope.

This is source review, not release acceptance. Live Saivage progress after the
pin may supersede findings. Report files are work evidence, not public docs.

## Independent critical triage

A fresh Astra challenged the consolidated allegations and proposed later repairs:
[triage receipt](98-CRITICAL-TRIAGE-REVIEW.md). **APPROVED, no actionable scoped
corrections.** It confirms evidence/impact distinctions and minimal fixes, with
diagnostic prefix/notice preservation cautions incorporated into the issue file.
This does not lift review-only authorization or certify runtime correctness.
