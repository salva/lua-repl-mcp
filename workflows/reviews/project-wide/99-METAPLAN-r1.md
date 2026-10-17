# Project repair metaplan

## Baseline and scope

Implement fixes against current source after comparing it to reviewed
`8383c03e1d1b38fb33a0573f80aeecdf179673ee`. This plan covers F01–F13 inventory
and their linked work packages. Preserve pure-Lua embedding, trusted execution,
public APIs, capacities, single-consumer results and TERM20/KILL10/retry1s cleanup.
No shared-runtime changes, process-tree sandbox, arbitrary new argument caps or
compatibility framework. Publication is a separate operator-owned operation,
not proof of release acceptance and not autonomous deployment permission.

## Sequence and dependencies

| Batch | Findings/work packages | Importance / transversality | Acceptance |
| --- | --- | --- | --- |
| A: reliable gates | [F11](F11-test-containment/03-plan-r1.md), claim corrections [F12](F12-evidence-claims/03-plan-r1.md) | 4/4, 2/2 | Failure-injected timeouts/partial frames/perpetual pending are bounded and fixtures contained; historical classification explicit |
| B: data/public boundaries | [F01](F01-locale-numbers/03-plan-r1.md), [F03](F03-limit-context/03-plan-r1.md), [F05](F05-error-shapes/03-plan-r1.md) | 5/4, 5/5, 4/4 | Locale-safe exact values/counts, effective custom limits, legal max fit, all actual error outputs schema-valid |
| C: evaluator and ingress | [F06](F06-invocation-boundary/03-plan-r1.md), [F09](F09-optional-traceback/03-plan-r1.md), [F08](F08-ingress-robustness/03-plan-r1.md) | 4/3, 3/2, 4/3 | Preparation failures stay local, optional debug absent, duplicate-ID/invalid-envelope recovery preserves sessions |
| D: lifecycle authority/progress | [F13](F13-completion-arbitration/03-plan-r1.md), [F02](F02-guardian-control/03-plan-r1.md), [F04](F04-fatal-wait/03-plan-r1.md), [F07](F07-failure-provenance/03-plan-r1.md) | 4/5, 5/5, 4/3, 4/4 | Decided event authority; real legal-max control latency, original deadlines, truthful terminal outcomes and failure provenance |
| E: documentation and release evidence | [F10](F10-source-links/03-plan-r1.md), final [F12](F12-evidence-claims/03-plan-r1.md) | 3/3, 2/2 | Repository and generated journeys valid; current claim-to-assertion mapping, actual installed and client qualification |

Do F13's design gate before D runtime implementation; it can run concurrently
with B/C analysis but not with overlapping source edits. Batch B establishes the
shared context/result surface used by C/D. F07 mapping can be specified during B
but ownership propagation is implemented with D. Keep changes to the same files
serialized. Do not spawn many overlapping fix cards for one transport/state batch.

## Validation and delivery

Per batch, retain a minimal regression for each concrete finding and run focused
tests, `python3 docs/check_contracts.py` and `git diff --check`. Run Lua tests on
qualified versions with exact environment records; report missing native/locales/
browser dependencies as blocked coverage, not runtime failures. Use the corrected
installed runner, outside checkout, no inherited module fallback. At D completion
rerun full lifecycle/cancellation/resource/installed tests and actual MCP-client
returned-tool evidence, not merely saved evidence parsing. At E build the strict
deterministic site, validate source and staged links/content/downloads and browser
desktop/mobile/keyboard paths. Website publication does not waive any gate.

For each coherent batch, commit changes and evidence using the configured owner
identity. On regression stop dependent work, preserve red evidence, and make a
reviewed corrective/revert commit limited to the batch; never reset or discard
unrelated changes. No forced push or history rewrite is part of repair execution.

## Simplification and retained constraints

Owner mandates and proven ownership/value safety remain. Remove accidental
codec defaults, full-snapshot retransmission, ambiguous test globs and duplicated
watchdogs where the chosen fixes subsume them. Prefer a small explicit boundary
over extra layers, review gates or generic frameworks. Historical evidence stays
work documentation, not a reason to preserve defects or claim unrun acceptance.

## Handoff

The root planner must adopt this work through supported records, reconciling
current source and existing cards rather than replaying finished work. Ask the
normal Run control to resume only if stopped; leave running work uninterrupted.
Capture accepted task/brief locators and actual executor activity; queued notice
alone is not adoption. Any concrete contradictory owner outcome is escalated;
implementation itself is delegated to the existing project process.
