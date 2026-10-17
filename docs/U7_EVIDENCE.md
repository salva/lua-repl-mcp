# U7 focused admission/framing repair

This increment repairs the six gaps reproduced by `tests/u7_bounds_red.lua`
(commit `8d8803d`), not full PLAN U7 or sibling U8 acceptance.

## Owning primitives

- `manager.lua`: request-handle admission independent of JSON-RPC bindings;
  ordinary/control/kill-only counters; cancellation and successful commit release
  slots, rejected send retains them. Allocation checks the live inventory before
  invoking the backend, including implicit creation. Starting and terminating
  workers retain session capacity until cleanup removal.
- `limits.lua`: validated admission defaults 64 sessions, 256 ordinary, 32 control,
  8 kill-only. Overrides are supplied as `manager.new{admission={...}}`.
- `framing.lua`: inspect chunks before concatenation, preserve preceding complete
  frames, retain at most limit+1 bytes of the offending frame, sticky rejection.
  Legal complete frames and raw lifecycle handoff remain unchanged.

The unchanged red reproducer passes with zero gaps. `tests/u7_admission.lua`
adds configured bounds, slot release, failed commits, terminating session reuse,
24 general controls plus 8 reserved kills, fragmented/coalesced frames and handoff.
This establishes logical retention bounds, not real client buffer high-water marks.

## Verification

Lua 5.4.6, existing project-local luaposix 36.3-1 tree.

```sh
lua5.4 tests/u7_bounds_red.lua
lua5.4 tests/u7_admission.lua
lua5.4 tests/u5.lua
lua5.4 tests/u6_deadlines_red.lua
lua5.4 tests/u6_policy.lua
export LUA_PATH='./?.lua;./?/init.lua;./.luarocks/share/lua/5.4/?.lua;./.luarocks/share/lua/5.4/?/init.lua;;'
export LUA_CPATH='./.luarocks/lib/lua/5.4/?.so;;'
lua5.4 tests/u6_ordering.lua
for t in tests/u1.lua tests/u1_diagnostic_notice.lua tests/u1_public_entrypoint.lua \
 tests/u1_review_invalid_key.lua tests/u2.lua tests/u2_handler_entrypoint.lua \
 tests/u2_review_argument_matrix.lua tests/u2_review_false_arguments.lua; do lua5.4 "$t"; done
python3 tests/u2_live.py
python3 tests/u5_process.py
python3 tests/u6_process.py
python3 docs/check_contracts.py
git diff --check
```

All completed successfully. An initial regression command reached U6 ordering
before exporting native paths and failed import of posix.unistd; corrected and
reran that check and all remaining checks successfully. U5/U6 real suites validate
28/21 responses. Contracts: 14 schemas, 7 tools, 2 discovery results, 23 examples,
125 regressions. No real bounded client transport, slow/stopped reader fairness,
short-write disconnect closure, complete-response budgeting, coupled transport
configuration or near-default encoding/ID measurements are established here;
those accepted-brief U7 requirements remain open.

## Continued implementation (3278262, 0aab697)

The preserved `tests/u7_encoding_red.lua` now passes: encoded values of
16777215/16777216 bytes yield complete responses of 33554621/33554623 bytes;
16777217 value bytes remain rejected. `protocol.tool_result` uses an explicit
payload budget, not the input/value default. `protocol.encode_result` preflights
the complete response and returns a small replacement plus `original=false` on
overflow. A replacement must not consume the retained execution payload.

New `client_transport.lua` is a native-independent connection transport seam:
nonblocking plain-function read/write adapters use `nil,'again'` for EAGAIN;
submit/cancel expose manager admission; step accepts a raw-frame callback for
U8 lifecycle/RPC routing. Worker timers advance every tick. Reads/writes have
64 KiB quotas, frame callbacks 16/tick; buffered complete input is drained before
another read. Entire retained output strings (including already-written prefixes)
count against the output bound. Short writes retain offsets, overflow/failure/EOF
calls manager disconnect and cleanup. This is not full MCP initialization or
conformance routing. Configured transport bounds are not yet coupled/validated
against all possible worker results and IDs.

Commands (native environment as above):

```sh
lua5.4 tests/u7_encoding_red.lua
lua5.4 tests/u7_transport.lua
(ulimit -n 256; timeout 25 lua5.4 tests/u7_transport_process.lua)
lua5.4 tests/u7_bounds_red.lua
lua5.4 tests/u7_admission.lua
lua5.4 tests/u5.lua
lua5.4 tests/u6_policy.lua
lua5.4 tests/u2.lua
python3 tests/u5_process.py
python3 tests/u6_process.py
python3 docs/check_contracts.py
git diff --check
```

Completed checks pass. Real stopped pipe tests record 65536 bytes short-output
progress while retaining exactly 200001 bytes against 134217728 output bound.
Closing the actual reader produces EPIPE and cleanup with empty worker/session
inventory during startup, execution and transmission. Deterministic output fills
exactly 2048 bytes then rejects the next enqueue. These are explicit retained
buffer measurements, not constant-RSS claims. A fixture initially failed after
commit-return checking was added because its fake commit omitted the real
manager's response return; corrected fake contract and reran successfully.

**Still open:** exhaustive coupled configuration/worst-case mathematical proof,
max legal escaped ID and default-scale control/quote/backslash/depth/diagnostic
payload coverage; real transport saturation/timer/kill-reserve fairness and legal
max result with unrelated session alive; all-limit boundary mapping. These are
required U7 work, not deferred to U8 and not an external blocker. The ASCII
reproducer passes but does not complete original acceptance.

## Coupled-default counterexample (4aaa599)

A materially different next attempt tested the actual maximum legal ID together
with an escape-heavy legal result. `lua5.4 tests/u7_coupled_defaults_red.lua`
completes **exit 1**, not acceptance. Exact measurements:

- Public session_wait request: 16777216 bytes (including all request fields).
- ASCII ID: 16777075 bytes; the remaining request overhead is 141 bytes.
- Values array: 16777216 bytes, containing 8388606 backslashes.
- Complete response with required session metadata, structuredContent and equal
  compatibility text: **67109058 bytes**, exceeding 67108864 by **194** bytes.
- Existing bounded encoder correctly emits a limit_exceeded replacement without
  partial original frame; that is not the required legal-maximum-result delivery.

Independent Python stdlib `json.dumps(...,separators=(',',':'),sort_keys=True)`
reconstructs the same request overhead, value size and complete response size.
This does not depend on Lua codec allocation estimates or an unproved bound.
Mathematically each value backslash needs two bytes in structured JSON and four
inside the re-escaped compatibility string. Thus the two representations alone
cost approximately 3V. A legal ID takes approximately I, where I=V at defaults;
3V+I fills all 64 MiB before mandatory envelopes/metadata. The concrete counts
above establish overflow using only standard required fields, no notices.

SPEC14.4 simultaneously fixes 16 MiB input/values, 64 MiB complete responses,
and requires a legal maximum result to fit, with maximum legal request ID in U7.
There is no smaller ID bound in the specification. Raising the response default,
restricting legal IDs, or reducing legal values changes an owner requirement.
Rejecting default configuration also violates required runnable defaults. An
owner decision on that conflict is required to finish exhaustive coupling:
raise complete response/output budgets as needed, specify an ID bound, or
explicitly narrow the legal-maximum fit guarantee. No normative limit was
silently changed. Other previously listed incomplete U7 tests remain incomplete;
this conflict is not evidence that those independent tests pass.
