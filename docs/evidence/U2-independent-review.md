# Independent U2 / U1 pointer diagnosis

Target: U2 `caf9af5`, including U1 repair `e1168a4`. Review for [[card:card-c-c]], implementation owner [[card:card-c-a]]. No implementation changes, native imports, or contract relaxations.

## Actionable R1: explicit false arguments close attachment

`lua5.4 tests/u2_review_false_arguments.lua` **exits 1** at the invalid-arguments assertion. Actual output:

```
Observed false-argument close status: closing
Observed lifecycle close_request_id: 2
Observed trailing execution: nil
```

The fixture initializes, submits `tools/call` with `name="repl_close", arguments=false`, then a valid execute and valid close. Expected: an `invalid_arguments` tool result (`isError=true`, no close action), execution admitted, final valid close acknowledged with ID 4. Actual: successful closing payload and lifecycle return for ID 2, so the valid trailing execution is not run. Raw handoff is not itself broken: stopping admission for this invalid close is the defect.

Owning cause: `protocol.lua` uses `p.arguments or codec.object({})` before calling contracts.validate. Lua false is conflated with absent arguments. Authoritative `api.json` close input is an object; SPEC 14.1/14.2 require valid tool failures to use error results and enforce input contracts. `contracts.validate` already rejects false; repair should preserve explicitly present values at the shared protocol boundary, defaulting only absent arguments. Please route repair to implementation owner. This review intentionally leaves the regression red, with no broad implementation repair.

## Other review observations

Read PLAN full U2 acceptance, SPEC 14.1/14.2/14.5 and relevant ordering text, MCP initialization/discovery examples, authoritative schema usage via live checker, `docs/U2_EVIDENCE.md`, and [[card:card-c-a]] accepted status v11. Inspected handler, framing, protocol, contracts, U1 pointer diff and regressions, U2 scripted/live host fixtures.

Branch comparison: handler validates options/adapters, invokes plain functions, loops positive partial writes, flushes before claiming acknowledgement, returns close context on close transport failure, preserves EOF tail and raw handoff, leaves unread bytes with adapter, and never selects cleanup. Framing is decode-free. Protocol gates tool use on initialized, supports version fallback/ping/discovery, separates protocol errors from validation results, and ignores direct cancellation rather than killing host. The false-default branch is the concrete exception above. Existing suites meaningfully cover every split size, short writes, errors and exceptions, all lifecycle reasons, coalesced close/replay, limits, invoking coroutine, native blocking and host continuation.

U1 `e1168a4` repairs the shared pointer primitive rather than transport symptoms: invalid UTF-8 key components use containing object paths, valid slash/tilde paths remain escaped. Independent rerun of original binary-key cases, escaped parent, raw codec/contracts and U2 wire recovery passes. No new U1 defect found.

## Executed verification

Lua 5.4.6; Python 3.12.3. At unchanged `caf9af5`, sequential `set -e` run passed:

```
lua5.4 tests/u2_handler_entrypoint.lua
lua5.4 tests/u2.lua
python3 tests/u2_live.py
lua5.4 tests/u1_public_entrypoint.lua
lua5.4 tests/u1.lua
lua5.4 tests/u1_diagnostic_notice.lua
lua5.4 tests/u1_review_invalid_key.lua
python3 docs/check_contracts.py
```

Exit 0: nine U2 groups, 14 U1 groups, entrypoints, diagnostic matrix, pointer regressions and live host passed; checker reports 14 schemas, seven tools, two discovery results, 23 examples, 125 regressions. Complete combined source inspection/runtime output: `work:///cards/card-c-c/processes/proc-d4142abd3c52/stdout.log`. That first run used system jsonschema 4.10.3; pinned validation is recorded in status.md. The independent red fixture ran separately and is not erased by those successes.

Classification: **failing_test**, not acceptance. Adequate existing coverage of many branches did not cover this malformed tool argument/lifecycle combination. This bounded diagnosis does not certify U3–U9 or begin later workflow verification.
