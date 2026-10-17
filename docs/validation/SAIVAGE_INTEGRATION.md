# U10 — refreshed installed Saivage integration

## Current classification

**Meaningful focused coverage passes** against package-ready revision
`1007245423b48b5ff36f5b69638d75608c451247`, local 0.1.0-1, on 2026-10-17.
Actual installed-server Saivage agent trials were rerun; the old runtime-unchanged
reuse argument is no longer applicable. No project server defect observed.
Saivage's shared-stdio client deadline limitation remains **NOT FIXED**:
operator filed https://github.com/salva/saivage-v3/issues/8.
Loss of unrelated sessions at client timeout is not a preservation pass.
Diagnosis is coverage_ready; workflow-owned verification remains separate.

U7 capacity correction is accepted upstream in this workspace: default worker
64 MiB, response 128 MiB, output 256 MiB with uniform fit floors. Current installed
maximum-ID/value test passes original delivery 67109058 <= 134217728. The
hardcoded old 64 MiB reproducer still intentionally exits 1; the suite explicitly
asserts that historical result. It is not a current U7 blocker.

## Provenance and affected branches

Read AGENTS.md, workflows/LAUNCH.md and OPERATIONS.md, PLAN U10, current U8/U9
refresh evidence and parent brief. Compared package changes from 5da1952 to
1007245: limits and wrapper/worker/transport defaults increased; fit validation
changed; supervisor now retries TERM on monotonic schedule, escalates to KILL
at 20 seconds, ends cleanup at 30, reaps before signalling, and bounds creation
metadata. Accordingly reran real-agent allocation/state/error/deadline/kill/
disconnect paths, rather than revalidating old JSON alone.

Historical original acceptance is preserved verbatim in
[history/SAIVAGE_INTEGRATION-5da1952.md](saivage/history/SAIVAGE_INTEGRATION-5da1952.md).
Its unresolved-U7 and runtime-unchanged claims apply only to that old trial.
Original attempt1/2/3 JSON and interpretation remain under `saivage/`; current
trial evidence is exclusively `saivage/refresh-1007245/`. Prior results are not
presented as fresh. The old history's relative links are historical paths; use
this document's current evidence links for navigation.

## Versions and isolated configuration

- Package revision exactly 1007245423b48b5ff36f5b69638d75608c451247 when installed;
  all 18 installed modules byte-equal checkout in the complete installed suite.
- Saivage dedicated mounted release **39ffe231** per deployment receipt,
  runtime package 0.1.0 (mount has no Git metadata); no runtime patch/restart.
- Node 24.16.0, Lua 5.4.6, LuaRocks 3.8.0; installed luaposix 36.3-1,
  bit32 5.3.5.1-1, Python 3.12.3, jsonschema 4.19.2.
- Fresh classic-typed isolated project; Analyst route openai-codex primary /
  gpt-6.1-sol. Supported init/YAML and POST /api/chat, not generated state edits.
- Loopback 127.0.0.1:18081 only, development auth disabled. Do not expose port.
  Provider/model/compaction configuration and mode-0600 credential copy only;
  no credential values logged or committed. Copy removed afterward.

Sanitized server entry (actual paths constructed by `tests/u10_setup.mjs`):

```yaml
mcpServers:
  lua:
    transport: stdio
    command: REFRESH_ROOT/u9-clean-reproducer/rocks/bin/lua-repl-mcp
    args: []
    env:
      LUA_PATH: REFRESH_ROOT/u9-clean-reproducer/rocks/share/lua/5.4/?.lua;REFRESH_ROOT/u9-clean-reproducer/rocks/share/lua/5.4/?/init.lua
      LUA_CPATH: REFRESH_ROOT/u9-clean-reproducer/rocks/lib/lua/5.4/?.so
    autostart: false
    disabled: false
```

No checkout runtime search path. The fresh project cwd is
`$SAIVAGE_CARD_WORK_ROOT/u10-refresh/u10-diagnosis/project`.

## Exact reproduction

From checkout at package revision above, use a new purpose-named card child.
The commands below reproduce the executed environment (run start in an owned
background command, do not restart the development service):

```sh
export REFRESH_ROOT="$SAIVAGE_CARD_WORK_ROOT/u10-refresh"
mkdir -p "$REFRESH_ROOT"
SAIVAGE_CARD_WORK_ROOT="$REFRESH_ROOT" sh tests/u9_installed.sh
mkdir -p "$REFRESH_ROOT/u10-diagnosis/project" "$REFRESH_ROOT/results"
(cd "$REFRESH_ROOT/u10-diagnosis/project" &&
 node /opt/saivage/bin/saivage.js init --profile classic-typed)
SAIVAGE_CARD_WORK_ROOT="$REFRESH_ROOT" node tests/u10_setup.mjs
node /opt/saivage/bin/saivage.js start \
 --project-root "$REFRESH_ROOT/u10-diagnosis/project" --host 127.0.0.1 --port 18081
# Separate command after launch; each waits for the actual Analyst response:
python3 tests/u10_agent.py --output "$REFRESH_ROOT/results/agent.json"
python3 tests/u10_agent.py --instructions tests/u10_followup.txt \
 --output "$REFRESH_ROOT/results/followup.json"
python3 tests/u10_evidence.py "$REFRESH_ROOT/results/agent.json" \
 "$REFRESH_ROOT/results/followup.json"
```

Bounded instructions are retained in u10_agent.py and u10_followup.txt. The first
fresh agent returned 44 tool invocations; follow-up 18, including actual MCP
results and final agent interpretation. Request watchdog 600s; client timer 30s;
Lua sleep workloads max 65s. Installed full suite ran concurrently with the first
trial; both completed, no shared module mutation occurred.

## Current real-agent matrix

All row evidence: [agent.json](saivage/refresh-1007245/agent.json),
[followup.json](saivage/refresh-1007245/followup.json),
[actual agent interpretation](saivage/refresh-1007245/interpretation.md).

| Requirement | Current observation / outcome |
|---|---|
| launch/init/discovery/schema usability | PASS: explicit start running/toolCount:5, all five exact discovered schemas, binding returned and accepted on subsequent calls |
| explicit/implicit sessions | PASS: explicit session-1-1/2, implicit session-1-3; retained IDs reused |
| globals/functions/JSON/nils/no implicit return | PASS: n/add persist, values [42,null,{count:2,tag:json}], fresh globals [true,true], initial values [] |
| synchronous + async pending | PASS: completed structured results; zero wait running, list reports result_available:true without consumption |
| wait/single-consumer | PASS: [73] terminal then result_unavailable; later valid reuse returns [74] |
| recoverable errors and effects | PASS: syntax not_started/runtime started/serialization completed, all usable, executed assert verifies counters once and returns [true,1,1,42] |
| finite expiry vs hard deadline | PASS follow-up: execute wait 1ms -> running, unbounded wait -> [81], next wait unavailable; independent hard 100ms returns execution_timeout/terminated/unusable/process_exit_confirmed:true |
| list/kill/repeated errors | PASS: kill confirms exit; later wait/repeated kill unknown_session (no retained history) |
| unrelated sessions | PASS before client containment: independent pre-existing session returns [42] after errors/hard deadline. Not claimed across shared client timeout |
| client deadline/cancellation | DOCUMENTED CLIENT LIMITATION: null Lua deadlines with sleep65 -> Saivage timeout30000ms, next list server not running; start/new binding/empty list/fresh [42] is recovery, not state continuity |
| disconnect cleanup | PASS follow-up: running worker plus idle session visible before supported stop; new binding/restart empty, fresh [42], final kill/stop; independent process observations all absent at end |
| actual agent interpretation | PASS: pending vs terminal vs error explicitly distinguished; finite-wait timing shortfall of first trial acknowledged and fixed by follow-up; client loss not relabeled success |

The agent's first trial tried a finite wait after sleep2 had already completed;
that specific wait did not expire. It then observed finite execute pending and
kill, but the ordered complete pending/terminal/consumed witness is the follow-up.
An async hard-timeout session was already removed before later wait: unknown ID
is not fabricated into a delivered timeout result. Follow-up captures the fatal
response within execute. These observations are consistent with state ordering.

## Focused verification and independent comparison

- Fresh `sh tests/u9_installed.sh`: **exit 0**, all ten installed live groups,
  C host, 18 module identities and complete installed core/handler/manager suite.
  Includes maximum original payload delivery and real progressive cleanup
  TERM-resistant child escalation (~20.01s), unrelated session responsiveness,
  cancellation and disconnect. Primary complete log:
  `work:///cards/card-c-e-a/processes/proc-aa0916a2e131/stdout.log`.
  Stderr has installer notice, expected historical red assertion (not current
  default), and checker PASS14/7/2/23/125. Current default test explicitly passes.
- Genuine agent command exits 0:
  `work:///cards/card-c-e-a/processes/proc-3171f67e1ac3/stdout.log` (44 calls),
  `work:///cards/card-c-e-a/processes/proc-003e90d89df0/stdout.log` (18 calls).
- Semantic checker exits 0 on new pair **40 native responses**, and historical
  pair **39**, log `work:///cards/card-c-e-a/processes/proc-c5527f7291ff/stdout.log`.
  It checks JSON argument round trip rather than fixed model-chosen object keys,
  accepted once-only assertion output variants, and binding-scoped follow-up
  consumption. Earlier checker failure was a fixture assumption: fresh agent
  killed another finite-pending execution; it did not retrieve that result.
  Restrict ordered consumption to the designated return81 witness, not every
  pending task regardless of later kill. No server change made.
- Independent jsonschema validation: every fresh call input, **40** native output
  payloads, all five exact advertised input schemas satisfy current authority:
  `work:///cards/card-c-e-a/processes/proc-c179e1f390bf/stdout.log`, exit 0.
  Python AST, Node setup syntax and diff checks pass.

Read-only changed-branch assessment: fit floors protect legal outputs before
admission; normal return/error wrapping preserved. Supervisor's reaping-before-
retry and deadline-based termination exercised in fresh installed process suite
and agent timeout/kill/disconnect. Agent pending/terminal/error handling remains
usable under new defaults. Real-agent trials do not attempt 128MiB client output:
Saivage's independent 1MiB projected-result cap remains a separate client ceiling,
not proof of server capacity failure. Installed boundary tests own maximum sizes.

## Timeout report and cleanup

[Client report](../reports/saivage/stdio-deadline-containment.md): refreshed 1/1
30s attempt, cumulative 2/2 across original and refreshed trials. Operator filed
https://github.com/salva/saivage-v3/issues/8; **not fixed**, no runtime changes.
Independent installed cancellation preserves unrelated sessions while transport
stays open; Saivage closes that shared transport, so its larger blast radius is
client containment, not a Lua hard-timeout defect. No automatic replay.

Follow-up explicitly stopped MCP at end. Process observer (10 worker PIDs,
nonempty set, none remain) exit 0:
[processes.json](saivage/refresh-1007245/processes.json),
`work:///cards/card-c-e-a/processes/proc-e077a3eee9a8/stdout.log`.
It samples only commands containing this refresh root and worker_main, not sibling
instances. Owned isolated service PID23832 stopped via kill_process after MCP
stop; PID absent and loopback port closed. Private copied auth file removed.
Setup/runtime source in /opt never written, no shared restart, host/sibling
modifications, generated-state edits, push or publication. Disposable install/
project retained for reproducibility without copied credentials.

## Refreshed verify acceptance

**Accepted: scoped U10 suite and meaningful coverage**, with the documented
external Saivage client limitation allowed by PLAN U10. This supersedes the
coverage_ready classification above; it does not claim a fix for issue8 or
full-project release acceptance.

Verify reused the immediately preceding same-card refreshed clean-install/full
suite and genuine agent trials only after confirming runtime/package/test-suite
inputs unchanged between 1007245423b48b5ff36f5b69638d75608c451247 and 4be95d6.
No old-5da1952 unchanged assumption was used. The installed suite's expected
hardcoded64MiB historical failure is accounted for explicitly by u9_suite.py;
current production maximum fit, progressive termination and complete installed
suite pass. No unresolved failed current check was hidden by aggregate status.

Fresh verify commands (all exit0):

```sh
python3 tests/u10_evidence.py docs/validation/saivage/refresh-1007245/agent.json docs/validation/saivage/refresh-1007245/followup.json
python3 tests/u10_evidence.py docs/validation/saivage/attempt2.json docs/validation/saivage/attempt3.json
"$SAIVAGE_CARD_WORK_ROOT/u10-refresh/u9-clean-reproducer/venv/bin/python" docs/check_contracts.py
node --check tests/u10_setup.mjs
git diff --check
git diff --exit-code 1007245423b48b5ff36f5b69638d75608c451247 HEAD -- lua_repl_mcp lua-repl-mcp lua-repl-mcp-0.1.0-1.rockspec tests/u9_installed.sh tests/u9_suite.py tests/u8_live.py
```

Also freshly parsed Python fixture syntax, checked retained 10 worker PIDs and
isolated owner absent, port18081 closed and copied auth absent. Log:
`work:///cards/card-c-e-a/processes/proc-5755c0b96885/stdout.log`; complete stderr
records checker PASS14 schemas/7 tools/2 discovery/23 examples/125 regressions.
Independent schema/binding review freshly validates all call inputs,40 native
outputs, five exact advertised schemas and previously observed binding epochs:
`work:///cards/card-c-e-a/processes/proc-86ec9715ca37/stdout.log`.

Branch-by-branch review of actual returned evidence agrees with SPEC state and
error ordering: allocation/idle, execution pending, list availability without
consumption, terminal then result_unavailable, usable recovery with effects once,
kill then unknown ID, fatal hard deadline versus later unknown ID, and fresh
binding/empty inventory after client containment. Agent interpretation is retained
verbatim, including its limitations. Its first summary says45 calls; returned API
evidence contains44 invocations, the authoritative retained count used here.

Coverage is scoped rather than merely green: provider latency made short
subsequent waits nondeterministic, so finite expiry is observed in execute itself
and the follow-up has an explicit terminal-consumption sequence within its own
binding epoch. A separate finite-pending execution was deliberately killed;
no terminal-consumption claim is made for it. Live scheduling is not advertised
as deterministic regression machinery; stored evidence checks are deterministic.
Kill while still active is not proven by model latency; actual kill/disposal is
observed and installed real-process tests independently exercise active kill.
Disconnect has running+idle list evidence and nonempty process oracle, not merely
an empty replacement server. Real-agent returns/interpretation establish the
client boundary, while installed process tests establish rare/order/boundary
branches; neither is substituted for the other.

No further agent rerun was required with unchanged inputs. No service or secret
was accessed by verify. U7 blocker claims remain historical only. Client timeout
still destroys unrelated state: only before-containment unrelated usability and
post-restart new usability pass, never continuity across shared-stdio teardown.
