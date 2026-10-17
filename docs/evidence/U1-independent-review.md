# Independent U1 diagnosis at 6ac36e1

Review owner: [[card:card-b]]. Implementation owner: [[card:card-a]].
This is an independent implementation assessment of b11b7bc plus 6ac36e1,
not a specification review or verification-owned final acceptance. No U2 code
was implemented. **U1 is not ready for U2 acceptance: one reproduced defect.**

## Concrete finding R1 — unencodable serialization-error response

Severity: acceptance-blocking correctness defect. SPEC §§13.4–13.5, 14.3 and
PLAN U1 require strict rejection of invalid UTF-8 with safe error diagnostics
and no partial values. Returning a table with an invalid UTF-8 **key** correctly
selects `result_serialization_error`, but places the original invalid bytes in
`error.path`. Consequently `codec.encode` rejects the *failure response* at
`/error/path`. The usable evaluator therefore supplies no transmissible terminal
result to U2. This is not a demand to implement a handler now.

Reproductions: `tests/u1_review_invalid_key.lua` covers a top-level `0xFF` key
and a nested invalid surrogate key containing slash/tilde. Both assert completed
execution, serialization stage, no values, and exactly-once effects with subsequent
session usability; both fail the response encodability assertion. Lua 5.4.6,
command `lua5.4 tests/u1_review_invalid_key.lua`: **exit 1**, two failures,
complete inline stdout reports `invalid UTF-8 at /error/path`; complete inline
stderr reports the assertion at line 29.

Owner locations: `codec.lua` object branch constructs `ptr(path,k)` before
`quote(k,...)` rejects the invalid key; `evaluator.lua` forwards `problem.path`
and `errors.new` copies it without Unicode validation. Fix at the owning
serialization/pointer boundary, not a transport workaround. A valid containing
object pointer is available when the offending key cannot be expressed in JSON;
do not manufacture a replacement-key pointer that claims to identify a different
member. Preserve existing valid-key RFC 6901 escaping. Regression must pass
without permitting binary values or losing the serialization failure's execution
state/side-effect warning. No production repair was made by this review node.

## Coverage and branch review

Reviewed all six U1 modules and existing three runtime tests against exact
SPEC §§4, 12, 13, 14.2–14.5 and PLAN U1, with schema definitions consulted for
input and result shapes. Native searchers and C module paths are disabled by
the runtime suites. Existing tests are meaningful, not schema-only evidence.

| U1 obligation | Diagnosis |
| --- | --- |
| Pure-Lua loading/stable public null/no global installation | Public-entrypoint test and disabled native loaders pass; modules import only pure-Lua U1 modules. |
| All seven tools, required/unknown fields, arrays/objects, defaults and timeout bounds | `all_seven_contract_defaults_and_rejection` passes; inspected tool-specific validation, create-options dependency, omitted/null/zero/positive timeout branches. Allocation/state is deferred to later units. |
| Strict lexical numbers | `numeric_lexical_safe_boundaries` passes integer/decimal/exponent safe limits, adjacent unsafe and pre-rounding tokens; exact mantissa/exponent inspection precedes tonumber. Nonintegral rounding/underflow allowed, overflow and unsafe rounded integral rejected. Output subtype/range cases pass. |
| Unicode/strict JSON | Grammar, duplicate keys, escape/surrogate-pair and invalid UTF-8 cases pass. Output invalid strings pass strict rejection tests. Invalid-key failure path is **R1**, missing from prior suite. |
| Chunk semantics and environment | Persistent globals/functions, scoped locals, no expression fallback, exact return count and nils pass. One load and protected execution inspected; no rewriting/capture. |
| Argument conversion | Nested/positional null, fresh tables, retained global table distinctness, empty input arrays returning objects pass. Copy boundary preserves wire shape only until user output mapping. |
| Recoverable errors/side effects/no retry | Syntax/runtime/serialization recovery and exactly-once counters pass; R1 additional counter checks also pass before final assertion. |
| Raw table mapping and unsupported values | Functions, userdata, threads, cycles, holes, mixed/unsupported keys, nonfinite numbers, invalid strings, shared acyclic tables and empty objects covered; next/rawget and active-path cycle logic inspected. |
| Hostile values | Metamethod and thrown-value tests pass without conversion/iteration/index/length/equality callbacks; non-string input-key rejection inspected. |
| Bounds/pointers/no partial values | Encoded-byte, depth and default 16 MiB/128/64 KiB boundary tests pass; slash/tilde zero-based pointers and entire-payload rejection pass except R1's unencodable pointer. Coupled transport budgets remain U7, not waived. |
| Diagnostics and 6ac36e1 repair | Existing notice suite passes original reproducer and 14 boundary cases, including reservation-only truncation, combined fields, escaped bytes, UTF-8 clipping and notice-only capacity. Inspected actual retained-byte truncation computation; no defect in this repair found. |
| Output behavior | Print/io identities unchanged and explicit capture test passes; no module output overrides. Process/host integration remains later-unit evidence. |

## Exact checks and limits of approval

At source HEAD 6ac36e1, Lua **5.4.6**, Python **3.12.3**, jsonschema **4.10.3**:

- `lua5.4 tests/u1_public_entrypoint.lua`: exit 0.
- `lua5.4 tests/u1.lua`: exit 0, all 14 named groups.
- `lua5.4 tests/u1_diagnostic_notice.lua`: exit 0, original plus boundary matrix.
- `python3 docs/check_contracts.py`: exit 0, 14 standalone schemas, 7 official
  MCP Tools, 2 discovery results, 23 examples, 125 regressions. Supplemental:
  installed jsonschema is not pinned 4.19.2; no U8 acceptance claimed.
- `lua5.4 tests/u1_review_invalid_key.lua`: exit 1, both independent regressions.

Existing-suite complete output was read at
`work:///cards/card-b/processes/proc-5ccfb1fb1105/stdout.log`.
No source modifications, no U2 implementation, no push. Review adds only this
report and a deliberately failing durable regression. Classification:
**failing_test**, not coverage_ready despite the prior suites passing. Original
implementation owner should remediate R1 and rerun all focused suites; independent
review/verification may then assess the changed inputs. This report does not
pre-approve a future repair or later runtime acceptance.

## R1 repair-stage follow-up

The preceding report records the diagnosis at 6ac36e1, not the current repair
result. On the subsequent repair node, the requested concrete repair was made
at `codec.pointer`: invalid UTF-8 string keys resolve to the valid containing
object pointer, rather than copying binary bytes into diagnostic paths. The
encoder still rejects such keys with `invalid UTF-8`. Valid string keys retain
slash/tilde escaping; numeric array indices retain their prior representation.
This primitive also protects argument-validator unknown-field diagnostics.
No transport-specific workaround, replacement-key fiction, U2 work, or relaxation
of returned-value validation was introduced.

Extended `tests/u1_review_invalid_key.lua` checks exact containing pointers for
both original cases and an escaped parent key, no values, side-effect notice,
JSON-encodable responses, exactly-once execution and subsequent usability. It
also checks raw codec rejection and invalid unknown argument keys, and keeps an
explicit valid slash/tilde pointer check.

Executed with `set -e` on Lua 5.4.6 / Python 3.12.3 / jsonschema 4.10.3:

```sh
lua5.4 -v
lua5.4 tests/u1_review_invalid_key.lua
lua5.4 tests/u1_public_entrypoint.lua
lua5.4 tests/u1.lua
lua5.4 tests/u1_diagnostic_notice.lua
python3 --version
python3 -c 'from importlib.metadata import version; print("jsonschema",version("jsonschema"))'
python3 docs/check_contracts.py
git diff --check
```

All exit 0. Original R1 cases now pass, plus escaped-parent and primitive-path
checks; existing 14 U1 groups and diagnostic boundary matrix also pass.
Complete runtime output read at
`work:///cards/card-b/processes/proc-e716c90bb480/stdout.log`; schema checker
reported 14 standalone schemas, 7 official tools, 2 discovery results, 23 examples
and 125 regressions in complete inline stderr. Schema evidence remains
supplemental (not pinned U8 validation). No failed repair attempts or alternate
hypotheses were needed: the established invalid-path propagation diagnosis
converged at the shared pointer primitive. This is focused repair evidence,
not final acceptance or independent approval of the repair; verify owns that gate.
