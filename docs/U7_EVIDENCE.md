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

## Pending ownership flood repair

Preserved `tests/u7_pending_flood_red.lua` now passes. The manager marks a
slotless admission rejection explicitly; transport immediately encodes/enqueues
it under the existing complete-response/output budget instead of retaining an
unowned pending handle. `submit` also removes cancelled/done handles before
admitting another call, bounding no-tick cancellation churn. Requests with slots
retain original commit/cancellation semantics; rejects never bind a cancellable
ID or dispatch work. Output overflow still disconnects and cleans up.

`tests/u7_pending_ownership.lua` covers 256 ordinary + 24 general-control + 8
kill-only pending handles, rejected response ID/error equality, stopped-reader
output overflow/cleanup, 2048 submit/cancel cycles without a tick and inert
rejected IDs. The preserved flood now measures pending **256 -> 256**, with
**1506221** bytes explicitly charged to output (bound 134217728), instead of
4352 unaccounted handles. This is deterministic ownership coverage, not a claim
of real saturated transport fairness.

Commands completed exit 0:

```sh
lua5.4 tests/u7_pending_flood_red.lua
lua5.4 tests/u7_pending_ownership.lua
lua5.4 tests/u7_admission.lua
lua5.4 tests/u7_transport.lua
lua5.4 tests/u7_bounds_red.lua
lua5.4 tests/u5.lua
lua5.4 tests/u6_policy.lua
# Existing LUA_PATH/LUA_CPATH environment above:
(ulimit -n 256; timeout 25 lua5.4 tests/u7_transport_process.lua)
python3 tests/u5_process.py
python3 tests/u6_process.py
python3 docs/check_contracts.py
git diff --check
```

The 194-byte coupled-default reproducer remains deliberately red and unchanged;
only universal legal-maximum default-fit acceptance needs an owner decision.
Real saturated transport/timer/cancellation fairness, fragmented-worker/adversarial
payload and exhaustive boundary obligations remain open as previously listed.
No normative limits or failing acceptance expectations have been relaxed.

## Independent remainder: real fairness and adversarial/default-scale paths

Continued independently of the preserved coupled-default conflict. New tests:

| Test | Actual coverage / measurements |
| --- | --- |
| `u7_fairness_process.lua` | Three real workers, real nonblocking input/output pipes; 256 outstanding waits; 257th rejection, list/ping, cancellation suppression, accepted kill and confirmed reap; 24 general controls then 8 reserved kills; sustained ping traffic while a 30ms hard worker deadline still completes. Output high-water 150316/134217728 bytes, input high-water 507; latest run 408 ping ticks before timed reply. |
| `u7_maximum_process.lua` | Exact default 16777216-byte quote-heavy values from real worker through fragmented private pipe, manager snapshots, public duplicated encoding and real client pipe. Response including newline 50331991 bytes; output high-water identical versus 134217728 bound. Duplicate text equality and unrelated live session `return 42` verified afterward. |
| `u7_adversarial.lua` | Default-scale exact-bound backslash values (16777216 bytes, response 50331838), control values (16777216, response 36350828), next character overflow; duplicate text equality; nesting 127/128/129; diagnostics 65535/65536/65537 and escaped 8192-byte ID; value overflow classified result_serialization_error without values. |
| `u7_boundaries.lua` | Exact complete-response -1/at/+1, frame -1/at/+1, retained output 2047/2048/2049; explicit versus default clone-depth budget. |
| extended `u7_pending_ownership.lua` | Output overflow inside commit callback actually disconnects after non-reentry guard releases; invalid/unknown/nonintegral/false/infinite transport bounds rejected. |

Owning fixes uncovered by these paths:

- `codec.clone` accepts explicit encode/decode options. Manager snapshots select
  a result/envelope budget (64 MiB, depth160), not public input defaults. Previously
  a legal values array plus metadata, or maximum nesting plus result wrappers,
  could raise before public response preflight despite protocol wrapping repair.
  Public/default codec input limits remain unchanged.
- `client_transport.close` defers manager teardown only when inside the guarded
  manager commitment callback, then runs it immediately after return. Previously
  enqueue overflow called disconnect reentrantly; pcall swallowed its assertion,
  leaving closed transport with live owned sessions. Regression checks actual
  closed manager and empty bindings. Ordinary EOF/write failures still dispose
  immediately. Transport scalar bounds and output/response+newline coupling are
  validated; full legal-maximum coupling is NOT claimed.

Reproduction, using the native LUA_PATH/LUA_CPATH above:

```sh
python3 tests/u7_process.py
lua5.4 tests/u7_adversarial.lua
lua5.4 tests/u7_boundaries.lua
lua5.4 tests/u7_encoding_red.lua
lua5.4 tests/u7_pending_flood_red.lua
lua5.4 tests/u7_pending_ownership.lua
lua5.4 tests/u7_transport.lua
lua5.4 tests/u7_admission.lua
lua5.4 tests/u5.lua
lua5.4 tests/u6_policy.lua
python3 tests/u4_process.py
python3 tests/u5_process.py
python3 tests/u6_process.py
lua5.4 tests/u2.lua
python3 docs/check_contracts.py
git diff --check
```

All completed exit 0. `u7_process.py` provides independent process-group watchdogs
and cleanup, NOFILE256 test-only and disposable fixture root beneath the card
work root. The maximum-response test has a 110-second outer bound. No RSS claim:
queue measurements include the retained written prefix, not merely unsent bytes.
U4's 15 real-process groups rerun, including fragmented ready/result and oversized
worker-frame disposal. U5/U6 rerun with 28/21 schema-validated committed responses.

### What remains unaccepted

The coupled-default reproducer is unchanged and remains red/owner-decision
blocked solely for universal default legal-maximum fit. These tests do not waive
remaining independent completeness questions: an exact supported-configuration
matrix for values/worker/public budgets is not implemented (worker evaluator
limits are still fixed); worker-frame and input default-size below/at/above
mapping and explicit worker buffer high-water instrumentation still need fuller
coverage. The depth test proves codec table depth, not all depth128 manager
roundtrips. Max-ID diagnostic combinations and every small response/error case
also are not exhaustively enumerated. Full U7 is still not accepted.

A justified next independent attempt is centralized validated configuration for
worker evaluator and transport budgets (preserving mandated defaults), with
explicit worker-buffer high-water instrumentation and generated frame boundaries,
then maximum-depth real-manager response coverage. Any universal-fit coupling
must expose the 194-byte contract conflict rather than silently reject defaults
or narrow legal IDs. No new normative limit is authorized here.

## Worker-buffer instrumentation and default frame/depth closure

Added scalar supervisor `buffer_high_water` / `pending_high_water` counters,
updated only when storing a bounded incoming frame / execution command. Counters
retain no payloads. `tests/u7_frame_budgets.lua` exercises actual supervisor drain
with injected OS reads and decoder to isolate admission BEFORE decoding at the
full default 20971520-byte worker bound: retained peaks 20971519, 20971520,
20971520 for below/at/above frames; above never reaches decoder. It separately
checks actual codec public input frames at 16777215/16777216/16777217 bytes.
This injection test establishes storage admission, not OS throughput; real
fragmented-worker coverage remains in U4 and the U7 maximum fixture.

Extended real maximum fixture executes nested tables at depths127/128/129:
127/128 survive worker/manager/text duplication;129 returns serialization_error
without values. Full `python3 tests/u7_process.py` passes under its process-group
watchdog: worker buffer high-water **16777347/20971520**, command high-water166;
maximum client response/output high-water50331991/134217728; unrelated session
still usable. Saturated fairness rerun passes,417 ping ticks before deadline
reply. Frame test and process suite both exit0.

Additional fail-fast regression: pending-flood, ownership, exact boundary tests,
U4 fifteen real groups, U6 twenty-one validated responses, contracts and diff
checks all pass. Existing earlier independent results remain relevant where
inputs unchanged. Universal default coupled-fit reproducer remains deliberately
failing; no default or ID size changed. Central configuration propagation to
workers and full configured-value/frame/response coupling remain unimplemented,
so this is continued progress, not exhaustive original U7 acceptance.

## Configured budget propagation repair (after b3c5e01)

Preserved `tests/u7_configuration_red.lua` now passes: the independently invalid
4096-input/1024-response configuration is rejected at transport construction,
not after accepting an unanswerable request. No legal ID is silently narrowed.

`limits.connection` validates per-instance `input_bytes`, `values_bytes`,
`diagnostic_bytes`, `max_depth`, `worker_bytes`, `response_bytes`, `output_bytes`.
Manager option is `limits={...}`. Transport inherits the manager budgets; explicit
conflicting overrides on configured managers are rejected. Supervisor snapshots
limits before exec; worker receives only scalar authored configuration and uses
it for evaluator values/depth/diagnostics and private-frame encode/decode. Manager
snapshots and public response preflight select derived depth and response limits.
Worker command reads now use bounded framing before concatenating oversized input.
No module-global protocol limit mutation. Injected supervisors exposing budgets
must match manager configuration. Tests cover caller mutation isolation.

Independent configured budget checks use conservative payload envelopes:
`worker >= max(input,values,6*diagnostic)+65536`;
`response >= input+3*max(values,6*diagnostic)+65536`;
`output >= response+1`. Scalars are positive integers <=2147483647, depth<=512,
and diagnostics must hold the loss notice. A source diagnostic byte can encode
as at most six JSON bytes. Re-escaping already encoded JSON costs at most twice
its length, so structured plus compatibility copies cost at most three times
encoded payload; request ID's encoded representation is bounded by input.
64KiB is explicit conservative envelope headroom, NOT a proof of arbitrary cwd,
artifact-list or indefinitely growing session metadata fit. Those remaining
unbounded-metadata proof questions are inventoried below, not silently assumed.

Exact normative defaults (implicit or explicit) remain runnable and marked
`default_fit_unresolved=true`; the known194-byte contradiction is NOT hidden by
rejecting defaults or changing them. Other configurations must pass conservative
coupling checks. Legacy standalone transport test seams allowing response-only
small bounds remain supported for fallback behavior; explicit input overrides
must hold input+1024 for ID/error envelope. Such a seam is not a configured
full-manager universal-result-fit promise.

New tests:
- `u7_configuration.lua`: worker/response/output required -1/at/+1, invalid
  scalar/unknown/depth/diagnostic cases, manager->transport inheritance, conflicts,
  default flag, >16MiB configured values arithmetic, protocol isolation, mutation.
- `u7_configuration_process.lua`: two actual exec configurations, encoded values
 1024/2048, depths8/16, diagnostics256/512. Values -1/at/+1 and depth -1/at/+1
 traverse manager/public client pipe; overflow is serialization_error, diagnostic
 truncation fits budget; equal duplicate text. Inputs512/1024 are deliberately
 smaller than legal returned values. Worker peaks1155/69632 and2179/73728;
 output peaks2393/74241 and4441/82945. Added to process-group watchdog suite.

Commands: `lua5.4 tests/u7_configuration_red.lua`,
`lua5.4 tests/u7_configuration.lua`, native-path
`python3 tests/u7_process.py` and `python3 tests/u4_process.py`,
`python3 tests/u5_process.py`, `python3 tests/u6_process.py`; existing flood,
ownership/transport/boundaries/frame budgets, U5/U6 policy/U2, contracts and diff
checks. All completed checks reported in the status record, including one fixture
arithmetic correction (diagnostic budget dominates values), not hidden as a pass.

### Full U7 inventory after this repair

Implemented/evidenced: admission/session/control/kill limits and cancellation;
bounded client input/output with fair ticks; actual saturated waits/control/timer
progress; no-dispatch rejection; private pre-storage bounds; short write/EPIPE
cleanup; precommit complete-response fallback versus value serialization error;
default-scale ASCII/quote/control/backslash values, max depth, unrelated session;
per-instance worker/evaluator/encoder/transport configuration and independent
invalid-config rejection. Boundary evidence is distributed across admission,
frame budgets, adversarial, boundary, configuration and real-process tests above.

Residuals: universal mandated-default max-ID fit remains the exact194-byte
owner-decision blocker. Mathematical exhaustive metadata/list/cwd/artifact
headroom proof and generated maximum-ID *all* error/notice combinations are not
complete; a64KiB fixed metadata allowance is conservative policy, not proof of
unbounded metadata. Large configured values >16MiB are constructor-tested but not
yet a separate exec-scale test. Exhaustive all-limit Cartesian combinations and
all slow-reader schedules are not claimed. U8 external complete MCP conformance
remains separate. No universal full-U7 acceptance follows from focused green.
