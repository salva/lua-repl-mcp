# Project-wide review

## Scope and baseline

Review commit `8383c03e1d1b38fb33a0573f80aeecdf179673ee`: runtime, public
contracts, tests, packaging, user documentation and local website build.
Excluded: credentials, generated autonomous state, shared runtime/service code,
publication and deployment. A detached snapshot under workspace `tmp/` isolates
the review from concurrent implementation. Live source fixes are not authorized
in this review; approved work is handed to the owning project planner.

Writer: GPT-6.1 Sol (orchestrator). Independent auditor/reviewer: GPT-6 Astra
(`openai/gpt-6-astra`). Iterate until approved; escalate if the same objections
remain unresolved for two successive rounds. No claim of absolute perfection.

## Work checklist

- [x] Confirm scope, models, iteration policy and handoff with operator.
- [x] Pin clean snapshot without altering active runtime source.
- [x] Complete subsystem map and independent issue inventory.
- [x] Analyze findings and compare focused/one-level-up designs.
- [x] Iterate per-issue plans with Astra until approved.
- [x] Order approved work and review integrated metaplan.
- [x] Check baseline drift and communicate applicability.
- [ ] Notify owning/root planners through supported controls and verify adoption.
- [ ] Resume via supported Run if stopped; otherwise preserve running work.

## Findings

| Finding | Severity | Transversality |
| --- | --- | --- |
| [F01 locale numbers](F01-locale-numbers.md) | High | Codec/evaluator/both interfaces |
| [F02 guardian control](F02-guardian-control.md) | High | Architectural lifecycle/transport |
| [F03 limit context](F03-limit-context.md) | High | All data boundaries |
| [F04 fatal wait](F04-fatal-wait.md) | Medium | Manager/outcomes |
| [F05 error shapes](F05-error-shapes.md) | Medium | Both public surfaces |
| [F06 preparation](F06-invocation-boundary.md) | Medium | Evaluator/worker/host |
| [F07 provenance](F07-failure-provenance.md) | Medium | Worker/guardian/public errors |
| [F08 ingress](F08-ingress-robustness.md) | Medium | Protocol/correlation |
| [F09 traceback](F09-optional-traceback.md) | Medium | Pure host imports |
| [F10 source links](F10-source-links.md) | Medium | Repository/site journeys |
| [F11 containment](F11-test-containment.md) | Medium | Test infrastructure |
| [F12 evidence](F12-evidence-claims.md) | Low | Claims/applicability |
| [F13 authority](F13-completion-arbitration.md) | Medium | Contract/guardian/manager |

Independent audit and three-round planning review complete. Astra's final
[integrated verdict](99-METAPLAN-review-r3.md) is APPROVED: no remaining actionable
planning issues within scope. Each work package's APPROVED.md selects exact
analysis/design/plan editions; superseded drafts/reviews remain work evidence,
not alternative execution instructions. [Current metaplan](99-METAPLAN.md)
orders all findings. No implementation, release or absence-of-defects claim is
made. See [audit receipt](00-AUDIT.md).

Round1 closed deferred topology/authority, depth/copy, preparation/correlation
and nested containment definitions. Round2 closed transfer scheduling/large
metadata/queue capacity, private-frame fit and completed-cancellation semantics.
Round3 approved the selected contracts without new findings. Each round explicitly
assessed historical baggage and review-induced machinery.

Publication is excluded from this repair acceptance scope, but separately
authorized for the orchestrator: repository and Pages are public development
candidates. Saivage executors retain content-only/no-publish scope.

## Pre-handoff validation

Runtime modules, entrypoint, rockspec and tests have no diff from audited baseline
at handoff preparation. Operator publication changed README to the live site
(partially removing F10's root source-entry problem), site_url and candidate
status, not the remaining source-page link defects. Review every finding against
current source before execution. All13 exact selected phase editions have explicit
approved matching reviews; local review-document links checked. Contract gate
passes14 schemas,7 tools,23 examples,125 regressions. No fix implementation is
claimed by these structural/documentation checks.
