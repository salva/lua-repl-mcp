# U10 Saivage integration — diagnostic baseline

Status: **coverage gap**, not U10 acceptance or an external blocker.

## Target and authority

Package revision `5da1952465a581399c9d3768d10acea3171581ca` (0.1.0-1).
Read AGENTS.md, workflows/LAUNCH.md, workflows/OPERATIONS.md, docs/PLAN.md U10,
U8_EVIDENCE.md, U9_EVIDENCE.md and the accepted parent brief.
U10 requires actual Saivage agent returned tool evidence; independent stdio
conformance is explicitly insufficient.

## Focused diagnosis

Commands from project root:

```sh
sh tests/u9_installed.sh
node /opt/saivage/bin/saivage.js --help
mkdir -p "$SAIVAGE_CARD_WORK_ROOT/u10-diagnosis/project"
(cd "$SAIVAGE_CARD_WORK_ROOT/u10-diagnosis/project" &&
 node /opt/saivage/bin/saivage.js init --profile classic-typed)
```

Clean installation command **exit 0**. Installed luaposix 36.3-1 and bit32
5.3.5.1-1; jsonschema 4.19.2. Installed module resolution, native C host and
all ten named U8 live groups passed (including explicit/implicit persistence,
JSON, async/single consumption, recoverable errors, cancellation, finite wait,
hard deadline, kill, disconnect/reaping and independent worker responsiveness).
These are independent-client observations, **not** Saivage trial outcomes.
Complete log: `work:///cards/card-c-e-a/processes/proc-2154ed01489a/stdout.log`;
stderr contains only the fresh manifest rebuild notice. No product failure was
observed in this run. The separate inherited U7 maximum-ID contradiction remains
unresolved; this run does not exercise or waive that assertion.

Supported CLI help and fresh isolated init both exit 0. Saivage deployment is
recorded as release `39ffe231` in workflows/OPERATIONS.md; package metadata says
0.1.0. Exact deployed revision must be confirmed for the final trial.
Read-only runbook inspection confirms supported operator YAML `mcpServers`,
explicit start/stop, discovery and agent invocation controls. Dynamic registration
is independently permissioned and is not in this Executor's tool inventory;
this is **not** evidence that operator YAML or an isolated instance is unavailable.
No local `saivage` executable is on PATH; the documented Node wrapper works.

## Scenario coverage matrix

| Required U10 observation | Actual Saivage coverage at diagnosis |
|---|---|
| launch/initialize/discovery/schema usability | Not run; isolated project init only |
| explicit/implicit sessions, globals/functions, JSON | Not run |
| sync/async/pending/wait/terminal, single consumption | Not run |
| recoverable errors, list, kill, unrelated sessions | Not run |
| finite wait vs hard timeout | Not run |
| client deadline/cancellation and disconnect cleanup | Not run |
| actual agent interpretation of pending/terminal/error | No returned agent tool evidence yet |

No `tests/*u10*`, prior validation artifact, or Saivage bug report existed at
entry. U8/U9 coverage is meaningful for the installed server but does not cover
the accepted brief's client boundary. Therefore diagnosis is **coverage_gap**,
not passing coverage and not a manufactured failing server test.

## Preserved setup and next work

Only supported `init` generated the disposable isolated project. No isolated
service was launched and no provider credentials were read, copied or changed.
No active development instance configuration, runtime, host or sibling was
modified. Installed tree remains in `$SAIVAGE_CARD_WORK_ROOT/u9-clean-reproducer/rocks`;
empty initialized integration project remains in
`$SAIVAGE_CARD_WORK_ROOT/u10-diagnosis/project`. Test fixture cleanup completed
with the passing suite; no background command remains from diagnosis.

Subsequent implementation/coverage work must configure and launch that isolated
instance using authorized local setup, retain real returned agent tool evidence,
fill every independent matrix row, then write reproducible client-defect reports
only if observed. No external route has been exhausted or declared blocked here.
