# U8 — live MCP integration evidence

## Implementation and scope

Baseline `876db60` had manager policy and bounded transport but no external MCP
manager attachment. `server.lua` integrates them with **the same protocol core**
used by the direct handler. The core's asynchronous submit hook hands original
arguments to manager validation/admission; it does not execute code twice or
apply schema defaults itself. The manager remains owner of request correlation,
cancellation, retention and response commitment. The stdio entrypoint uses
nonblocking POSIX reads/writes, bounded transport ticks, SIGPIPE suppression and
bounded polling; stdout contains only MCP frames. EOF/output failure uses existing
connection-owned worker disposal. Manager discovery expands the five authoritative
schemas and descriptions; no Tasks or direct tools are advertised there.

Changed files: `lua-repl-mcp`, `lua_repl_mcp/server.lua`,
`lua_repl_mcp/manager_schemas.lua`, `lua_repl_mcp/protocol.lua`,
`tests/u8_stdio_red.py` (preserved red probe), `tests/u8_live.py`,
`tests/u8_direct_host.lua`, this evidence. U9 still owns rockspec/clean installation
and actual C embedding validation. The CLI expects normal installed module paths;
it deliberately does not hard-code a checkout location.

## Versions and reproducible commands

Observed Lua **5.4.6**, luaposix **36.3** (local rock **36.3-1**, previously
qualified U3), Python **3.12.3**, jsonschema **4.19.2** in a disposable venv.
Pinned official MCP 2025-11-25 schema revision
`86f6e0c675afea9a8f233e09b6faf566b126086c`, SHA256
`268a5f82ba70fd7e4b6dc4aa1e64f116f74b4d0edcb69dc046829c79dd4e97e7`.
Both live suite and documentation checker verify that digest before use.

Development commands, run from checkout (setup locations are operational, not
installation assumptions):

```sh
mkdir -p "$SAIVAGE_CARD_WORK_ROOT/u8-validation"
python3 -m venv "$SAIVAGE_CARD_WORK_ROOT/u8-validation/venv"
"$SAIVAGE_CARD_WORK_ROOT/u8-validation/venv/bin/pip" install jsonschema==4.19.2
PY="$SAIVAGE_CARD_WORK_ROOT/u8-validation/venv/bin/python"
eval "$(luarocks --lua-version=5.4 --tree=.luarocks path)"
export LUA_PATH='./?.lua;./?/init.lua;'"$LUA_PATH"
python3 tests/u8_stdio_red.py ./lua-repl-mcp
"$PY" -u tests/u8_live.py ./lua-repl-mcp
"$PY" docs/check_contracts.py
lua5.4 tests/u4_review_malformed_error.lua
lua5.4 tests/u4_error_contract.lua
lua5.4 tests/u4_error_drain.lua
lua5.4 tests/u2.lua
lua5.4 tests/u2_review_argument_matrix.lua
lua5.4 tests/u2_review_false_arguments.lua
python3 tests/u2_live.py
python3 tests/u5_process.py
python3 tests/u6_process.py
lua5.4 tests/u7_admission.lua
lua5.4 tests/u7_transport.lua
lua5.4 tests/u7_transport_process.lua
git diff --check
```

Reusable installed-CLI command for U9, including outside-checkout invocation:

```sh
# PY has jsonschema==4.19.2; use installation's Lua module environment only.
# TEST_SOURCE is this checkout, not a runtime module search path.
U8_WORK_DIR=/absolute/disposable/u8-fixtures \
  "$PY" "$TEST_SOURCE/tests/u8_live.py" /absolute/installed/bin/lua-repl-mcp
```

The optional `MCP_SCHEMA=/absolute/pinned-schema.json` enables digest-checked
offline live validation. Documentation checker uses `--mcp-schema` instead.
The suite locates test/schema source by its own file, not cwd; the manager CLI
command is replaceable. Direct fixture loads modules from the same installation
environment. Disconnect process ownership checks use Linux `/proc` as a test
oracle, not a product portability requirement.

## Named live outcomes

Final suite exits **0**, with these exact names:

- PASS `lifecycle_negatives_notifications_discovery_five_tools_ten_schemas`
- PASS `normative_explicit_persistence_null_returns_recoverable_errors_capture_output_isolation`
- PASS `normative_async_poll_single_consumer_success_error_out_of_order`
- PASS `cancellation_reply_suppression_kill_hard_deadline_worker_exit`
- PASS `finite_wait_busy_preservation_wait_cancellation_active_kill`
- PASS `external_256_wait_saturation_limit_ping_list_reserved_kill`
- PASS `external_manager_conformance`
- PASS `creation_cancellation_blocked_fifo_responsive_ping_reaped`
- PASS `explicit_relative_shared_output_exclusive_creation_disconnect_idle_running_blocked_startup_reaping`
- PASS `actual_dedicated_channel_direct_four_schemas_close_flush_handoff_parent_replay`

Evidence: `work:///cards/card-c-d-a/processes/proc-2f886ac8f634/stdout.log`.
Every live tool result is validated against the pinned official CallToolResult
and its independent standalone output schema, with exact `isError`/error
presence and decoded-text/structuredContent equality. All seven advertised
input/output schema pairs equal independently expanded authoritative definitions;
Tool/ListToolsResult/InitializeResult also use pinned official validators.
Initialization uses three-byte input fragments, unsupported-version negotiation,
pre-initialization discovery rejection and repeat initialization rejection.
Malformed JSON, array request, unknown method/tool, unknown notifications,
invalid/null arguments and omitted defaults are exercised.

Normative MCP_EXAMPLES scenarios are replayed semantically with generated RPC
and session IDs, temporary cwd and fresh output paths rather than literal
`/work/project`/`s1`/`s2`: explicit allocation, persistent counter and trailing
nil, implicit/null allocation with hard timeout, immediate pending then wait,
consumed result error, busy error, serialization failure with preserved side
effects, kill, cancellation, list, direct close, explicit capture and null.
Additional assertions cover locals vs globals/functions, syntax/runtime recovery,
output isolation including native subprocess output, out-of-order fast/slow
workers, two successful/failed waiters, finite waits vs hard deadlines, os.exit,
active kill and cancellation during allocation/execute/wait. At 256 ordinary
waits, overflow rejects without dispatch while ping/list/kill remain responsive;
one fatal-result consumer wins and 255 get result_unavailable.

Actual direct fixture passes separately supplied inherited **dedicated pipe FDs**,
not stdin/stdout, to handler. It calls a host API on the invoking coroutine,
observes live state, sends close+raw complete execute+partial tail in one pipe
write, checks close acknowledgement before parent record, asserts trailing code
did not run in handler, preserves bytes/order, replays complete message in parent,
then deliberately resets globals and closes handles. This is a Lua host fixture,
not U9's C host or a claim about arbitrary embedding APIs.

## Affected-path regressions and earlier attempts

- Red probe now PASS `external_manager_initialization` with CLI override; original
  default library candidate is intentionally unchanged (it remains a library).
- Pinned checker PASS: **14 standalone schemas, 7 official MCP Tools, 2 discovery
  results, 23 examples, 125 regression cases**. Initial red-stage check used
  jsonschema 4.10.3; final check used required 4.19.2.
- Independently scrutinized `876db60`: required/optional nested error fields,
  enum/type/null/array/unknown-field branches and valid evaluator error shapes
  pass. Malformed error cannot complete execution; supervisor disposes worker.
- All nine U2 groups, false arguments, argument matrix and live direct blocking
  close fixture pass after protocol hook addition. U5 real process tests pass
  **28** schema-checked responses; U6 pass **21**. No U1–U7 runtime changes needed.
- Actual short output/EAGAIN/EPIPE and disconnect during startup/execution/
  transmission pass using shared owning transport: retained **200001** bytes,
  bound **134217728**, short progress **65536** each. U7 transport/admission pass;
  configured output high-water **2048**, bound **2048**.
- Two live test hypotheses were corrected, not product semantics: expecting
  cancellation cleanup before the next ping/list ignored asynchronous reaping;
  now bounded polling checks disposal. Expecting all 256 waiters to receive
  session_killed violated single-consumer semantics; now exactly one receives
  it, 255 result_unavailable. Both initial assertions failed and final reruns pass.

Focused regression output:
`work:///cards/card-c-d-a/processes/proc-2720a7333d25/stdout.log` and stderr.log;
U5/U6/transport regressions:
`work:///cards/card-c-d-a/processes/proc-124f88e084d5/stdout.log`.

## Honest unresolved row

**BLOCKED OWNER DECISION — U7 legal maximum fit**, not waived by U8:
unchanged `lua5.4 tests/u7_coupled_defaults_red.lua` fails the normative assertion:
legal request/value each **16777216** bytes needs **67109058** response bytes,
exceeding **67108864** by **194**. Small limit_exceeded fallback is not successful
original delivery. Reproduced during red assessment; inputs/runtime encoder are
unchanged. No authority to alter these requirements; independent U8 implementation
and tests are not delayed. No claim that all project acceptance is green.
U9 clean install, newer interpreter matrix and C host, and U10 Saivage integration
remain separate follow-on work, not evidence supplied by this increment.
