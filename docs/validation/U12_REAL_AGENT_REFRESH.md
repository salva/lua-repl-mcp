# U10 real-agent refresh on U12

[[card:card-d-c]], add-coverage continuation, 2026-10-17. Package checkout
`e9913e8df54607e831c3bcdccdd05892eca20a64`; runtime/CLI/rockspec byte-identical to
459f7fa, including af80aa9 relay and9f82e55 EOF fixes. Reused only the clean
installation and combined independent stdio/host/lifecycle acceptance recorded in
[U12_COMBINED_VERIFY.md](U12_COMBINED_VERIFY.md), whose relevant inputs are unchanged.
**All agent calls below are new**, not reused1007245 results.

## Setup and reproduction

Saivage dedicated read-only mounted release39ffe231 per OPERATIONS deployment
receipt (no mount Git metadata), package0.1.0; Node24.16.0, Lua5.4.6,
luaposix36.3-1, bit32 5.3.5.1-1, jsonschema4.19.2. Fresh classic-typed project,
same supported provider/model route as earlier trial. No runtime patches.

```sh
W="$SAIVAGE_CARD_WORK_ROOT/u12-verify-combined"
mkdir -p "$W/u10-diagnosis/project" "$W/results"
(cd "$W/u10-diagnosis/project" && node /opt/saivage/bin/saivage.js init --profile classic-typed)
SAIVAGE_CARD_WORK_ROOT="$W" node tests/u10_setup.mjs
node /opt/saivage/bin/saivage.js start --project-root "$W/u10-diagnosis/project" --host 127.0.0.1 --port 18081
python3 tests/u10_agent.py --output "$W/results/agent.json"
python3 tests/u10_agent.py --instructions tests/u10_followup.txt --output "$W/results/followup.json"
python3 tests/u10_evidence.py "$W/results/agent.json" "$W/results/followup.json"
```

Supported isolated YAML/credential setup only; active configuration is read-only.
Private credential copy mode0600 removed after stopping isolated service. Sanitized
MCP entry: stdio command `$W/u9-clean-reproducer/rocks/bin/lua-repl-mcp`, args[],
autostart:false, disabled:false; LUA_PATH exclusively that tree's
`share/lua/5.4/?.lua;share/lua/5.4/?/init.lua` (each prefixed by tree), LUA_CPATH
exclusively tree `lib/lua/5.4/?.so`. Loopback18081 development-auth disabled;
never exposed or used active service. Runtime cwd is fresh project above.

## Actual evidence and matrix

Retained [agent calls](saivage/refresh-u12/agent.json),
[follow-up calls](saivage/refresh-u12/followup.json),
[actual agent interpretation](saivage/refresh-u12/interpretation.md).
Interpretation extracted from only assistant text in supported
GET `/api/agents/agent%3Aanalyst%3Aglobal/conversation`, not model summary invented
by validator. POST chat returns toolInvocations, not final text.

| Requirement | Current witness / classification |
|---|---|
| Launch/init/discovery/schema bindings | PASS: supported start; five exact discovered tools, returned bindings used |
| Explicit/implicit/isolation/persistence/JSON/nils | PASS: explicit1/2, implicit3; add(2),null,JSON round trip; fresh globals true,true; no-return values[] |
| Async/list/nonconsumption | PASS: running then list result_available:true then73; reusable74 |
| Finite expiry/terminal/one consumer | PASS follow-up: execute1ms pending, wait81, subsequent result_unavailable |
| Recoverable syntax/runtime/serialization | PASS: not_started/started/completed classifications, session usable; executed assertions return null,1,1,42 |
| Kill/repeated kill | PASS confirmed killed then unknown_session; timing does not prove first sleep2 still active at kill; installed matrix covers actual active disposal |
| Hard deadline | PASS follow-up execute100ms/unbounded returns execution_timeout, unusable/terminated/confirmed; unrelated session42 in first trial |
| Client deadline/cancellation | FILED-NOT-FIXED limitation: sleep65/null deadlines yields client30000ms timeout, list server-not-running. Restart empty/new42 is recovery, NOT continuity |
| Disconnect | PASS bounded trial: follow-up list running worker + idle session; stop without kill; new binding empty/new42; final stop; no installed-environment processes remain |
| Agent interpretation | PASS explicitly separates pending/terminal/tool errors, finite timing shortfalls, fatal removal, client-wide loss and new-instance recovery |

No fabricated timeout result from later unknown_session. Finite wait after model
latency in first trial had already completed; follow-up repairs missing observation
without changing runtime. Earlier failures remain in historical reports.
Issue8 https://github.com/salva/saivage-v3/issues/8 remains **filed, not fixed**.
No new client failure requiring new report observed. Independent current installed
stdio suite supports attribution: protocol cancellation/hard deadline and unrelated
sessions work there; client shared transport teardown is broader than Lua timeout.

## Focused checks and cleanup

Agent commands completed exit0,44 and18 actual calls:
`work:///cards/card-d-c/processes/proc-bc2c2d3d2397/stdout.log`,
`work:///cards/card-d-c/processes/proc-11ad8d513b5a/stdout.log`.
Initial semantic checker failed on overly narrow fixture output variant (executed
assert returned null,1,1,42 rather than existing allowed true,1,1,42). Preserved
failure: `work:///cards/card-d-c/processes/proc-0f674802f61e/stderr.log`.
Bounded harness correction accepts that equally meaningful asserted variant and
requires designated return81 finite pending witness (prevents vacuous loop pass).
No product changes or weakened outcome requirement. Updated checker passes current
40 native responses and historical1007245 pair40:
`work:///cards/card-d-c/processes/proc-872940d4eb3b/stdout.log`.
Independent jsonschema check validates all MCP call inputs and40 native outputs:
`work:///cards/card-d-c/processes/proc-10c0256f97d5/stdout.log`, exit0.

After agent stop, `/proc/*/environ` scan for this exact installation's module path
found zero processes: [oracle](saivage/refresh-u12/processes.json),
`work:///cards/card-d-c/processes/proc-d0a89d5ad973/stdout.log`.
Stopped only owned isolated service31839 via kill_process after MCP cleanup;
removed private credential copy, confirmed no18081 listener. No shared service
restart, host changes, generated-state edits, publication or public-doc rewrite.
Scoped coverage passes; final suite acceptance remains verify-owned.
