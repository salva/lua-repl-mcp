# U13 exact-edition/source reconciliation — batch A

Audit `8383c03e1d1b38fb33a0573f80aeecdf179673ee`; handoff/entry HEAD
`1c19aa3`. All APPROVED.md and selected editions were read before source edits.
`git diff 8383c03 1c19aa3 -- lua_repl_mcp tests lua-repl-mcp*` is empty.
Publication changed README/site_url/status, not runtime findings. Planning
approval is not implementation acceptance. Paths below are relative to this
folder; each directory contains the exact three linked editions. Evidence is
source inspection unless an executable command is explicitly cited.

| Finding / exact selection (analysis, design, plan) | Current source evidence and applicability | Ownership / remaining acceptance |
| --- | --- | --- |
| F01-locale-numbers: [a](F01-locale-numbers/01-analysis-r2.md), [d](F01-locale-numbers/02-design-r1.md), [p](F01-locale-numbers/03-plan-r1.md) | codec.lua:79 uses locale-sensitive %.17g; decoder uses tonumber. No runtime drift. Applicable. | B: centralized numeric conversion; actual C/comma locale and exact tuple count qualification. |
| F02-guardian-control: [a](F02-guardian-control/01-analysis-r1.md), [d](F02-guardian-control/02-design-r3.md), [p](F02-guardian-control/03-plan-r3.md) | guardian.lua relays full fields/result snapshots through one guardian_channel, gates receive on wire.busy; aggregate reports remain bounded as one frame. Applicable. | D: independent control/bulk/liveness, SERIAL FIFO, 64KiB/256-node quantum, validated admission-derived reserves, input-sized metadata bodies, original startup/disposal deadlines; installed default 63 retained + active workload. |
| F03-limit-context: [a](F03-limit-context/01-analysis-r1.md), [d](F03-limit-context/02-design-r3.md), [p](F03-limit-context/03-plan-r3.md) | contracts.lua calls codec.clone; codec.clone re-encodes/decodes with independent defaults; no immutable selected raw-field spans. Applicable. | B integrated F05: raw metatable-safe copier, D/D+1/D+8 and exact custom-floor input/worker fit, no new public ceilings. |
| F04-fatal-wait: [a](F04-fatal-wait/01-analysis-r1.md), [d](F04-fatal-wait/02-design-r1.md), [p](F04-fatal-wait/03-plan-r1.md) | manager.lua preview/wait decisions reconstruct readiness from timestamps rather than selected explicit commitment state. Applicable. | D: fatal outcome to outstanding uncommitted waiters; committed pending immutable, single consumption. |
| F05-error-shapes: [a](F05-error-shapes/01-analysis-r1.md), [d](F05-error-shapes/02-design-r1.md), [p](F05-error-shapes/03-plan-r1.md) | protocol.lua generic tool-error/encode fallback; handler close has distinct schema. No shared operation/outcome constructors. Applicable. | B: tool-specific schema-valid outer errors; no schema widening; every fallback branch validated. |
| F06-invocation-boundary: [a](F06-invocation-boundary/01-analysis-r1.md), [d](F06-invocation-boundary/02-design-r2.md), [p](F06-invocation-boundary/03-plan-r2.md) | evaluator.lua:22 unpacks outside protected invocation, traceback handler unprotected. Applicable. | C: trampoline entry marker, exact limit_exceeded/execution/not_started and idle usable state, no arbitrary arg cap. |
| F07-failure-provenance: [a](F07-failure-provenance/01-analysis-r1.md), [d](F07-failure-provenance/02-design-r1.md), [p](F07-failure-provenance/03-plan-r2.md) | worker_supervisor startup failures/manager output still use private failure strings and mirrored fields, no selected typed mapping interface. Applicable. | B mapping before C; D native propagation, actual observed exit facts only, original failure retained. |
| F08-ingress-robustness: [a](F08-ingress-robustness/01-analysis-r1.md), [d](F08-ingress-robustness/02-design-r2.md), [p](F08-ingress-robustness/03-plan-r2.md) | server.lua decode/manager bind; manager.bind asserts uniqueness, manager.cancel deletes completed reservation. No single ingress reservation owner. Applicable. | C using fixed F13 contract, D integrated races: -32600/null duplicate, false vs parse failure, release only commitment/suppression. |
| F09-optional-traceback: [a](F09-optional-traceback/01-analysis-r1.md), [d](F09-optional-traceback/02-design-r1.md), [p](F09-optional-traceback/03-plan-r1.md) | evaluator.lua:8 unconditional debug.traceback import. Applicable. | C paired F06: missing/failing traceback preserves primary error and pure-Lua host imports. |
| F10-source-links: [a](F10-source-links/01-analysis-r1.md), [d](F10-source-links/02-design-r1.md), [p](F10-source-links/03-plan-r1.md) | Root README live-site entry partially repaired by owner publication; README-IF-YOR-ARE-AN-AI.md/source references still use stage-relative destinations. Remaining defect applicable, root change must not be replayed. | E: small shared source/stage mapping, strict repeated builds and local desktop/mobile/keyboard; no deployment. |
| F11-test-containment: [a](F11-test-containment/01-analysis-r1.md), [d](F11-test-containment/02-design-r2.md), [p](F11-test-containment/03-plan-r2.md) | Entry u9 glob includes U12 spawning fixtures; nested wrappers own sessions; website frame/pending checks incomplete. Four bounded red assertions preserved. | A: external Linux subreaper independent of product, explicit manifest, inherited ownership, complete-frame/total deadlines and crash tests. Linux-only qualification does not alter POSIX product support. |
| F12-evidence-claims: [a](F12-evidence-claims/01-analysis-r1.md), [d](F12-evidence-claims/02-design-r1.md), [p](F12-evidence-claims/03-plan-r1.md) | WEBSITE.md recipe receipt overstates ownership/handoff and total watchdog scope. RELEASE.md predates separately published candidate. Applicable narrative drift. | A narrow initial corrections only; E current claim-to-assertion applicability, actual live tool evidence, no saved parser substituted. |
| F13-completion-arbitration: [a](F13-completion-arbitration/01-analysis-r2.md), [d](F13-completion-arbitration/02-design-r3.md), [p](F13-completion-arbitration/03-plan-r3.md) | guardian completion timestamps and manager refresh/application/cancel still conflate eligibility and authority; completed cancel drops request entry. Applicable. | D coordinated F02/F04/F07: guardian eligibility, manager application, public commitment; completed cancel INERT, active cancel destructive/suppressed. |

## Boundaries and evidence

Batch A changes test infrastructure and truthful claim text only. No B–E runtime
repair or release acceptance is claimed. Fixed owner contracts, strict conversion,
capacities, pure handler, explicit returns/no capture/public task IDs and original
TERM20/KILL10 at 1s through 30s abandonment remain unchanged. Valid historical
U1–U12 receipts are preserved. The record status for card-f-a-a gives red/green
commands and limitations; infrastructure regressions are in tests/u13_*.py.
