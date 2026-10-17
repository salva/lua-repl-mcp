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

# Add-coverage: actual isolated agent trial

The diagnostic matrix above is historical. The gap is now covered by genuine
Saivage Analyst tool calls, not by the independent client alone. Package sources
unchanged at `5da1952`; repository at diagnostic commit `b802283` when run.
Deployment release `39ffe231` per deployment receipt (read-only runtime, no Git
metadata); runtime package 0.1.0, Node 24.16.0. Lua 5.4.6, luaposix 36.3-1,
bit32 5.3.5.1-1; installation and comparison suite as recorded above.

## Reproduce in an empty card work root

```sh
sh tests/u9_installed.sh
mkdir -p "$SAIVAGE_CARD_WORK_ROOT/u10-diagnosis/project"
(cd "$SAIVAGE_CARD_WORK_ROOT/u10-diagnosis/project" &&
 node /opt/saivage/bin/saivage.js init --profile classic-typed)
node tests/u10_setup.mjs
node /opt/saivage/bin/saivage.js start \
 --project-root "$SAIVAGE_CARD_WORK_ROOT/u10-diagnosis/project" \
 --host 127.0.0.1 --port 18081
# In another owned command:
python3 tests/u10_agent.py --output /disposable/attempt2.json
python3 tests/u10_agent.py --instructions tests/u10_followup.txt --output /disposable/attempt3.json
python3 tests/u10_evidence.py /disposable/attempt2.json /disposable/attempt3.json
```

Fixture uses supported init, operator-owned YAML and POST /api/chat. Setup copies
only provider/model/compaction configuration and mode-0600 credentials into the
isolated project without displaying them; active instance is read-only. Loopback
18081 uses development auth-disabled mode. Do not expose that port externally.
Sanitized connection: `lua`, stdio, installed `rocks/bin/lua-repl-mcp`, empty args,
installation-only LUA_PATH/LUA_CPATH, autostart:false, disabled:false. Exact
path construction is in u10_setup.mjs. Agent instructions are in u10_agent.py
and u10_followup.txt. Agent route is openai-codex primary / gpt-6.1-sol.

## Actual outcomes and meaningful assertions

| Scenario | Evidence/outcome |
|---|---|
| launch/init/discovery/schema use | start returned running/toolCount:5; all five exact input schemas and fresh binding delivered; calls admitted |
| explicit/implicit, globals/functions, JSON, nulls | attempt2 returns [42,null,{tag:json,value:7}], [true,true] independent globals, implicit object; no implicit returns [] |
| sync/async/list/single consumer | pending running; list result_available:true; terminal [73], then result_unavailable; session reused |
| finite expiry vs terminal | attempt3 execute wait_timeout_ms:1 -> running, unbounded wait -> [81], next wait -> result_unavailable |
| recoverable syntax/runtime/serialization | errors preserved with isError:true and session_usable:true; side effects [null,1,1] exactly once |
| kill/repeated kill | successful confirmed process disposal then unknown_session; no retained history invented |
| independent hard deadline | attempt3 execute 100ms/unbounded wait -> execution_timeout, terminated/unusable, process_exit_confirmed:true |
| unrelated session use | attempt2 old independent session returns [42] after recoverable and hard-deadline scenarios |
| client deadline/cancellation | 30s Saivage timer -> client error, entire stdio server unavailable; old unrelated sessions lost; explicit restart empty then [42]. **Client limitation**, report below |
| disconnect while idle/running | attempt3 list shows idle session and running session/result_available:false; explicit stop, restart empty; process observation captured PIDs 14724/14733/14741, none remain |
| actual agent interpretation | retained interpretation.md explicitly distinguishes pending, terminal, tool-error and client timeout, and identifies initial timing limitations corrected by follow-up |

`saivage/attempt2.json` retains **43** returned invocations; follow-up
`saivage/attempt3.json` retains **18**. Checker passes all eleven named categories,
ordered finite-pending/terminal/consumed sequence, JSON/isolation/once-only effects,
hard-vs-client deadline distinction and text/structured equality/isError mapping
for **39 native MCP calls**. Focused final command exit 0:
`work:///cards/card-c-e-a/processes/proc-73f1a0bea1c8/stdout.log`.

Earlier failures are retained honestly: first agent attempted non-existent wildcard
names instead of omitting optional toolName (36 calls, no invocation; fixture
exit 1), retained as attempt1.json. This is agent misuse, not demonstrated server
or client schema failure; exact-name instructions fixed it. First attempt2-only
checker failed missing hard_timeout because async fatal session had already been
removed before a later wait. Follow-up captures fatal response in execute itself;
combined checker passes. No product semantics were patched to satisfy tests.

Client containment report: [stdio-deadline-containment](../reports/saivage/stdio-deadline-containment.md).
Frequency 1/1 targeted timer attempt; independent installed U8 cancellation and
disconnect comparison passes. Saivage closes the shared stdio transport rather
than preserving unrelated sessions. No public issue, runtime patch or server fix.

## Cleanup and limits

Agent stopped MCP after each completed trial; follow-up confirmed exit of new
session and final stop. OS observer exit 0, observed workers absent at end:
`saivage/disconnect-processes.json`, command log
`work:///cards/card-c-e-a/processes/proc-85998ee52f13/stdout.log`.
Stopped owned isolated service using kill_process after MCP stop; PID 14546
absent, loopback port refused connections (curl exit 7). CLI `stop` only stops
project execution, not service: its contained:false response was not treated as
service cleanup. Removed isolated credential copy; active credential file intact.
An initial copy command used isolated cwd and failed; rerun from root retained
process evidence correctly. No shared restart, sibling/host edits or publication.

This increment adds coverage; final suite acceptance remains verify's work.
Inherited U7 maximum-ID contradiction remains unresolved and unwaived. No claim
that every project gate passes or that client deadline preserves unrelated state.
