# Independent U3–U7 diagnosis at 04a41d5

Review for [[card:card-c-b-f]], diagnosis only; no acceptance waiver or U8 claim.

## Results

- **Observed failing test:** unchanged `lua5.4 tests/u7_coupled_defaults_red.lua` exits 1 at line30. Legal input and encoded values are each16777216 bytes; required complete response67109058 exceeds67108864 by194. Independently reconstructed with Python stdlib compact sorted JSON: exactly the same sizes. This is a normative coupled-default contradiction, not permission to shrink IDs/values, raise defaults, reject required defaults or call fallback successful original delivery. SPEC14.4 and PLAN U7 demand worst-case legal-ID fit. Owner decision remains required.
- **Concrete additional U4 robustness defect:** new `tests/u4_review_malformed_error.lua` exits1: private `worker_protocol.decode` accepts a generation-tagged failed result with `error={}`. `worker_protocol.validate` checks only that error is a table; it does not validate required error fields/types or unknown error fields. `worker_supervisor.receive` consequently can record it as a completed generation, and manager/protocol copying/encoding does not repair it. Public schema `$defs/error` requires code/message/stage/execution_state. Owning repair scope is private result validation, not output symptom replacement. This is malformed-worker fixture coverage, **not** a claim ordinary evaluator output produces empty errors, arbitrary-code security containment, or an ordinary runtime crash found in live suites.
- No additional ordinary runtime failure observed in the executed real-process/regression paths. Green focused coverage does not prove every schedule or waive the known red case.

## Independently executed inventory

Environment: Lua5.4.6; existing local luaposix36.3-1/bit32 tree; Python3.12.3; system jsonschema4.10.3. Native commands use:

```sh
export LUA_PATH='./?.lua;./?/init.lua;./.luarocks/share/lua/5.4/?.lua;./.luarocks/share/lua/5.4/?/init.lua;;'
export LUA_CPATH='./.luarocks/lib/lua/5.4/?.so;;'
```

- All standalone Lua tests existing at target passed, excluding process/host/presence/posix fixtures invoked by their Python drivers and the separately run deliberately red coupled-default test. Includes U1/U2, U5 deterministic policy, U6 deadlines/policy/15 ordering permutations, U7 admission/adversarial/boundaries/configuration/frame budgets/max-ID/metadata/pending ownership/snapshots/transport.
- `python3 tests/u2_live.py`: supplied-channel host/close/continuation pass. Independently inspected231b36e nil-only argument defaulting and reran both R1 false-argument and type-matrix tests: explicit invalid arguments do not stop admission; omitted arguments still default.
- `python3 tests/u3_posix.py`: seven binding qualification groups pass, including real EINTR/EAGAIN/EPIPE, exec paths/CLOEXEC, blocked child/second child, kill/reap and owned-FD cleanup. Qualified local Linux environment only.
- `python3 tests/u4_process.py`:15 groups pass: startup failures/FIFO isolation/partial artifacts, streams/cwd/exclusive permissions, fragmentation/stale/duplicate frames, FD inheritance, independent exit and bounded writes. Does not cover the newly exposed missing nested error validation.
- `python3 tests/u5_process.py`:28 committed responses schema-validated, independent workers, one-time execution/consumption, generation replacement, waits/implicit allocation pass.
- `python3 tests/u6_process.py`:21 schema-validated responses; infinite/native blocking execution, deadlines/cancel/disconnect, confirmed reap and injected30s fallback pass.
- `python3 tests/u7_process.py`: all five watchdog groups pass.20MiB configured actual exec values20971520; private peak20971651/25165824; client output62914903/134217728. Default maximum values16777216; private peak16777347/20971520; output50331991/134217728. Unrelated session survives; depth127/128/129 covered. Real256 waits, reserved controls, cancel/kill and sustained traffic deadline progress pass (315 ping ticks); output high-water150316. Stopped-reader retained200001 with65536 short progress; EPIPE cleanup pass for startup/execution/transmission.
- `python3 docs/check_contracts.py`:14 standalone schemas,7 tools,2 discovery results,23 examples,125 regressions pass **using system4.10.3, not pinned4.19.2**. This run is supplementary, not pinned-schema/U8 external acceptance.

## Source/requirement comparison

Read AGENTS, PLAN, relevant SPEC/defaults/schema, U3–U7 evidence and owning transport/manager/supervisor/private protocol/worker code. Compared readiness/abort and stale generation ordering, wait origins/replacement, preview versus commitment/consumption, deadline freeze versus exit drain, cancellation and cleanup, slot release and reserved kills, bounded pre-storage framing, output failure deferred teardown, configured propagation and precommit fallback. Existing focused checks substantiate these branches with the qualification above. Snapshot copy preserves shapes/null and isolates owned tables without imposing public wire bounds. Non-default conservative payload inequalities support completed values/diagnostics; aggregate metadata relies on bounded fallback, not universal original-list delivery. Default I+3V already fills4V before mandatory wrappers, explaining the independent counterexample.

U7 supplies a nonblocking transport seam with raw-frame callback, manager submission and cancellation. It is not the U8 full MCP lifecycle/stdio routing or official external conformance suite. Packaging/clean installation and real host/client release gates are not established here.

## Evidence and reproducibility

- Full passing regression command/output: `work:///cards/card-c-b-f/processes/proc-6caf403f872f/stdout.log` (exit0; stderr records checker counts). Command loops standalone `tests/*.lua` skipping `*process*|*host*|*posix*|*presence*|*coupled_defaults*`, then runs the five Python drivers above and checker fail-fast.
- U7 real suite output: `work:///cards/card-c-b-f/processes/proc-6c83b09a7d57/stdout.log`, exit0.
- Independent Python reconstruction and first malformed fixture output: `work:///cards/card-c-b-f/processes/proc-9602cc603945/stdout.log` / stderr. Its sequential shell ended0 because Python passed **after** Lua failed; this does not erase the failure. Standalone rerun `lua5.4 tests/u4_review_malformed_error.lua` exits1 (`proc-c8715c02427b`).
- Original coupled reproducer standalone exit1 measured194 excess (`proc-a28d740d2e1b`, complete inline output).

Changes: one minimal deliberately failing malformed-error fixture and this evidence document; no production/spec/default change. Diagnosis classification: **failing_test**. Full acceptance remains withheld; later verification owns acceptance, and an owner decision is needed for normative default fit.

## Repair follow-up

On explicit repair direction, `worker_protocol.lua` now validates the entire nested public error shape at the owning private boundary: required fields, enums, optional types/ranges, object/array/null distinctions and unknown fields. Both encode and decode reuse that validation; invalid frames therefore reach the existing supervisor corrupt-worker disposal path without recording a completion. Valid evaluator syntax/runtime/serialization failures remain accepted. No schema/default/ID or fallback policy changes.

The original `u4_review_malformed_error.lua` is unchanged and now passes. New `u4_error_contract.lua` covers omitted required fields, wrong optional types, invalid enums/ranges/pointers, unknown fields, array/null errors and valid optional/evaluator shapes. `u4_error_drain.lua` uses a real nonblocking pipe and supervisor drain to prove error={} causes terminating/corrupt_worker, closed descriptor and no result. It does not claim child-process reaping by itself; existing real suites cover that disposal machinery.

Native environment is unchanged from above. Repair verification commands: `lua5.4 tests/u4_review_malformed_error.lua`, `tests/u4_error_contract.lua`, `tests/u4_error_drain.lua`, `tests/u6_ordering.lua`, `tests/u5.lua`, `tests/u6_policy.lua`, then Python U4/U5/U6/U7 process drivers (fail-fast). Additional max-ID/configuration/snapshot, R1 argument matrix/false and supplementary contract checks pass. Detailed final process status belongs in status.md. The unchanged coupled-default test was rerun separately and still exits1 with exactly194 excess; this is not a fixture defect and cannot be repaired without an owner requirement decision. No full acceptance or U8 conformance claim follows from repairing nested validation.
