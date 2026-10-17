# Independent suite acceptance at 546ccf2

Verification for [[card:card-c-b-f]]. Accepted scope: affected U3–U7 runtime,
approved capacity correction and the explicitly requested supervisor escalation
repair. **PASS / done for this card**, not U8/U9/U12 release acceptance.

## Fresh verification and stable inputs

Working tree and HEAD checked:546ccf2, clean; no source/test changes since the
immediately preceding repair evidence. Inspected supervisor abort/step/reap,
phase helper, deterministic policy and real-child fixture against SPEC14.4.
Cause/origin freeze precedes TERM; idempotent abort preserves them; polling wakes
for retry/phase/total deadlines; reaping precedes retry; phase switch at20s is
independent of retry timestamp; one signal per turn prevents catch-up;30s cutoff
prevents late signalling and releases managed inventory with truthful exit flag.
No changes to value limits/IDs/consumption or handler import graph.

Fresh commands with project-local LUA_PATH/LUA_CPATH documented in prior evidence:
- `lua5.4 tests/u6_progressive_policy.lua` three times: all pass.
- `lua5.4 tests/u6_review_progressive_termination.lua`: initial15 required15.
- `python3 tests/u6_progressive_process.py`: real TERM-resistant child,20.0103s,
 1967 responsive turns, KILL confirmed/reaped; exit0 under28s isolated watchdog.
- `lua5.4 tests/u7_default_maximum.lua`: current production defaults, legal input
 and values16777216 each; response67109058/134217728 original success, echoed ID
 and compatibility equality; exit0.
- `lua5.4 tests/u7_review_preallocation.lua`: incompatible/overflow capacity
 rejection before backend construction; exit0. `git diff --check` passes.
Complete fresh batch output: `work:///cards/card-c-b-f/processes/proc-df551f5431f6/stdout.log`.
- Created disposable `$SAIVAGE_CARD_WORK_ROOT/verify-contracts` venv, installed
 jsonschema==4.19.2 and ran its Python on `docs/check_contracts.py`: exit0,
 14 schemas/7 tools/2 discovery/23 examples/125 regressions. This supersedes the
 earlier supplementary system4.10.3 check for this gate. Output:
 `work:///cards/card-c-b-f/processes/proc-54563d677a22/stdout.log`, stderr pass counts.

## Applicable reuse and coverage reasoning

Reuse same-card terminal exit0 evidence documented in accepted status v13 and
`docs/evidence/U6-progressive-repair.md`: repair batch at unchanged source
`work:///cards/card-c-b-f/processes/proc-79098d26bbea/stdout.log`, supplementary
`work:///cards/card-c-b-f/processes/proc-1efd2793bb66/stdout.log`. This is directly
applicable post-supervisor-change evidence, not pre-repair green carried across
changed inputs: U4 fifteen real groups, U5/U6 28/21 schema-validated responses,
all five U7 watchdog groups, ordering, malformed nested errors, configuration,
metadata flood and handler isolation. Original broader capacity batch at b8464fb
is reused only for unchanged codec/limits/admission boundary coverage; changed
supervisor paths use the post-repair tests instead.

Meaningful acceptance combines mathematical bounded encoding/metadata ownership,
exact below/at/above and pre-storage tests, fake-clock rare races/unconfirmed-exit
models, and real FD/process/pipe behavior. Deterministic repeated tests establish
phase stability without sleep timing. Real child uses an explicit TERM-ignore
readiness barrier, monotonic elapsed bound and actual WNOHANG reap; its20s phase
is well inside28s watchdog, not a lucky subsecond race. Real saturated transport
covers256 waits, control/kill reservation, cancellation and deadline progress;
retained-buffer peaks count written prefixes, not constant RSS. Maximum default
and20MiB configured result tests include unrelated worker survival and exact text
duplication. Snapshot fallback cannot consume original results; metadata notices
are capped at two; malformed worker errors cannot become terminal payloads.
These cover distinct state/ordering/error branches, not merely constructor green.

Historical `u7_coupled_defaults_red.lua` remains intentionally nonzero for its
hardcoded obsolete64MiB bound; original194-byte overflow preserved separately.
The new production-default success test, not this historical assertion, is the
current acceptance target. No known current affected-suite failure remains.

## Limits of acceptance / handoff

No infinite schedule enumeration, RSS constancy, portability beyond qualified
Linux/luaposix, descendant sandbox, external client or installed release claim.
SPEC14.9 independent guardian/manager crash and signal ownership remains PLAN U12,
not implemented or waived here. The scoped supervisor escalation is accepted;
it is not acceptance of that later architecture. U8 owner refresh stdio/live/
direct-host tests; U9 owner fresh clean install and installed U8/host/module-exec
checks. After U12 ownership changes rerun affected cleanup/deadline/fairness/
resource/install/client suites; this card's result cannot certify changed inputs.
No runtime setup changes, push, publication or sibling acceptance.
