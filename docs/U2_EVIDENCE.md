# U2 implementation evidence

## Architecture and adapter contract

`handler.serve(adapter, options)` loads only pure Lua modules. `protocol.lua` owns
MCP lifecycle, discovery, request correlation and tool/protocol error separation;
its injected tools/call policy is reusable by the later manager. `framing.lua`
owns raw byte splitting; it does not decode handoff frames. `handler.lua` owns
blocking adapter operations, never resources. Evaluation remains U1's existing
global-environment evaluator, with no expression fallback or output capture.

Options: `input_bytes` (16 MiB), `response_bytes` (64 MiB), `read_bytes` (65536),
`evaluator` (U1 evaluator limits), `instructions` (host API text). Invalid options
return `handler_error`. Adapter exceptions are transport errors. Read/write/flush
are plain functions with SPEC 14.5 signatures. Every response is flushed. Close
returns after its acknowledgement flush or attempted transport failure; only a
successfully written and flushed closing result sets `acknowledgement_sent`.
No close/shutdown/reset/exit occurs inside the handler. Raw complete trailing
frames and incomplete bytes are returned without decoding; unread bytes remain
with the adapter. EOF preserves incomplete data. Oversized input stops attachment;
response overflow is budgeted before any frame write and becomes limit_exceeded.

Discovery schemas in `direct_schemas.lua` are generated from api.json by
`docs/check_contracts.py.expand`, with direct descriptions from that same checker.
`tests/u2_live.py` detects schema drift and validates live direct payloads.

## Reproduction and final commands

Original `lua5.4 tests/u2_handler_entrypoint.lua` failed with missing handler.
The unchanged reproducer now passes. All commands below ran from repository root:

```
set -e
lua5.4 tests/u2_handler_entrypoint.lua
lua5.4 tests/u2.lua
python3 tests/u2_live.py
lua5.4 tests/u1_public_entrypoint.lua
lua5.4 tests/u1.lua
lua5.4 tests/u1_diagnostic_notice.lua
lua5.4 tests/u1_review_invalid_key.lua
python3 docs/check_contracts.py
```

Exit 0. U2: entrypoint, nine named groups, live pipe fixture passed. U1: 14 groups,
public null, diagnostic matrix, invalid-key pointer cases passed. Checker: 14
standalone schemas, seven official MCP tools, two discovery results, 23 examples,
125 regressions passed. Lua 5.4.6; Python 3.12.3; Linux x86_64/glibc 2.39.
The system jsonschema was 4.10.3, so the required version was also installed and
both Python checks repeated successfully:

```
python3 -m venv "$SAIVAGE_CARD_WORK_ROOT/u2-validation"
"$SAIVAGE_CARD_WORK_ROOT/u2-validation/bin/pip" install jsonschema==4.19.2
"$SAIVAGE_CARD_WORK_ROOT/u2-validation/bin/python" docs/check_contracts.py
"$SAIVAGE_CARD_WORK_ROOT/u2-validation/bin/python" tests/u2_live.py
```

## Acceptance coverage

- Every chunk size from one byte through the full combined protocol stream;
  three-byte writes; coalesced requests; close write-prefix failure.
- Read errors, throws, empty/oversized reads; write errors, throws, zero/negative/
  oversized/noninteger progress; close flush errors/throws. No cleanup by handler.
- All four lifecycle reasons; context and acknowledgement gating; EOF tail.
- Close followed by malformed raw complete data, execute and partial execute;
  parent replay proves no early effects, loss or duplication. Separate unread
  adapter bytes test. Response overflow before output commitment.
- Pure loader with native loaders disabled; existing print/io functions unchanged.
- Real POSIX pipes to in-process Lua host fixture; host API asserts invoking
  coroutine, blocks in OS sleep, queued close produces no early response; execution
  precedes close; host continues, then parent explicitly resets and closes channel.
- Protocol errors vs invalid tool arguments, initialization/version fallback,
  initialized notification, ping, unknown methods/tools, direct-only schemas,
  ignored notifications (no destructive direct cancellation), text/result equality.
- Independent scrutiny of e1168a4: invalid UTF-8 pointer components must identify
  containing object, valid slash/tilde paths remain escaped. Existing U1 tests
  pass; new wire regression proves failure is JSON encodable and next execution
  recovers with once-only side effects.

## Limits of this evidence

This is U2, not a manager or packaging delivery. No POSIX manager imports,
workers, hard deadlines or destructive managed cancellation were added. The host
fixture validates a real Lua process and supplied dedicated pipes, not a third-
party embedding product. U7's coupled configurable bounds/fairness proof and U9's
product embedding integration remain separate plan work; no portability or
constant-memory claim is made. Handler has bounded input-frame reads, but output
encoding still uses the U1 codec. Deliberate hostile mutation of handler internals
by trusted full-access code is not a sandbox guarantee.
