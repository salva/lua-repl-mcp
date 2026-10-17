# U4 — supervised worker transport and startup

## Scope and internal integration seam

Implemented in `worker_protocol.lua`, `worker_posix.lua`, `worker_main.lua` and
`worker_supervisor.lua` under `lua_repl_mcp/`. The public handler/import tree is
unchanged and never imports these modules. Workers reuse the pure evaluator,
including its validation, persistent globals, null identity and error conversion;
there is no second MCP connection or output capture. The standard private-loop
wrapper exits after returning (including its graceful close path).

`worker_supervisor.new(options)` owns allocation generations, workers and a
monotonic clock seam. `allocate(create_options)` starts the deadline **before**
pipe/fork/exec. `step(timeout_ms)` services bounded nonblocking writes (64 KiB per
worker/step), drains (256 KiB per worker/step), startup deadlines, and independent
WNOHANG reaping. `execute(worker, direct_input)` reserves a generation only from
idle after validation/encoding. `abort`, `graceful_close`, and bounded `shutdown`
are internal seams, not public manager tools. `launch` allows controlled process
fixtures; production defaults to exec of `lua5.4`. Native search paths are carried
explicitly from the invoking runtime, not guessed after changing cwd.

Startup timeout: default **30000 ms**, integer range **1..2147483647 ms**;
false, nonfinite, fractional and out-of-range configurations are rejected.
Private protocol version 1 has exact envelope fields and typed per-message
fields, positive allocation/execution generations, and bounded JSON lines
(**20 MiB**, excluding newline). Unknown versions/fields/types, stale/duplicate
records and invalid execution/result shapes dispose of the worker. Readiness
must precede execution admission; no readiness observed at/after deadline or
post-abort can restore allocation.

Output setup is exclusive 0600 subject to umask, shared once for identical
stdout/stderr strings, and `/dev/null` device-open by default. Cwd, output opens,
then stdin open occur inside the worker. Each creation is reported before the
next setup operation. `created_paths` is evidence of **reported** paths (absolute
cwd-prefixed names, not symlink canonicalization). `files_complete` is true only
on readiness; all startup failures conservatively mark it false, including when
setup likely reported every creation. Known files remain on disk; unreported
creation can never be inferred from a dead worker. This truthful internal data
is available for later public `created_files`/`created_files_complete` mapping.

FDs 0/1/2 are initially detached from manager streams before exec. Intended
control ends survive this one exec, then receive CLOEXEC before setup. Both fork
branches close unused ends; worker closes unrelated inherited descriptors using
the POSIX `_SC_OPEN_MAX` ceiling. This portable sweep can be expensive with a
very high ceiling; it does not block the parent, and counts toward startup time.
Manager pipe ends are CLOEXEC/nonblocking; manager installs ignored SIGPIPE;
embedded handler signal policy is untouched. Fork-child setup is protected and
always `_exit`s on failure rather than unwinding into manager code.

## Reproduction / actual results

Tested Lua **5.4.6**, luaposix **36.3-1**, bit32 **5.3.5.1-1**, Linux environment
qualified in `docs/U3_EVIDENCE.md`. From checkout:

```sh
eval "$(luarocks --lua-version=5.4 --tree=.luarocks path)"
python3 tests/u4_presence.py
python3 tests/u4_process.py
python3 tests/u3_posix.py
for t in tests/u1.lua tests/u1_diagnostic_notice.lua tests/u1_public_entrypoint.lua \
 tests/u1_review_invalid_key.lua tests/u2.lua tests/u2_handler_entrypoint.lua \
 tests/u2_review_argument_matrix.lua tests/u2_review_false_arguments.lua; do
 lua5.4 "$t"
done
python3 tests/u2_live.py
python3 docs/check_contracts.py
git diff --check
```

The driver supplies explicit absolute source module paths and requires
`SAIVAGE_CARD_WORK_ROOT`; disposable files go in its `u4-process-tests` child.
A 45-second external process-group watchdog contains all fixtures/descendants;
Lua assertions use five-second local bounds and finally shutdown/reap owned
workers. The driver sets RLIMIT_NOFILE=256 **only for its test subprocess** so
subsecond timeout fixtures test message behavior rather than 524288-descriptor
sweep speed. A separate unrestricted smoke run reached ready, executed `return
42`, then confirmed reap. Tests use Linux `/proc` only to observe the FIFO
kernel wait and subprocess FD layout, not in production code.

Final focused suite: **15 PASS groups**, exit 0:
`work:///cards/card-c-b-b/processes/proc-d651d4e4536f/stdout.log`.
Presence reproducer now passes. Regression/contract batch exit 0 (before the final
fork-child error-containment tightening and additional oversized/fragmented-result
test, both then covered by the final focused rerun):
`work:///cards/card-c-b-b/processes/proc-5de296bdd179/stdout.log` and its stderr.
Contracts: 14 schemas, 7 MCP tools, 2 discovery records, 23 examples, 125 cases.
U3 seven capability groups and U2 explicit argument/default matrices pass;
no concrete U3 binding or U2 R1 defect found. Initial smoke accidentally omitted
checkout `?/init.lua` after LuaRocks path setup; corrected invocation, not modules.
An implementation configuration defect accepted false as default; fixed by
nil-only default, retaining explicit-false regression. Early subsecond process
fixtures expired during the high-ceiling descriptor sweep; bounded test-local
rlimit makes handshake timing controlled. FIFO concurrent-worker test uses a
four-second startup deadline and an observed kernel `wait_for_partner` barrier.

## PLAN U4 acceptance mapping (actual named tests)

| Requirement | `tests/u4_process.lua` group(s) |
| --- | --- |
| Readiness, persistence, recoverable evaluator errors, wrapper exit | `ready_persistent_globals_recoverable_errors_and_wrapper_exit` |
| Finite validated startup defaults, strict version/frame checks | `configuration_and_protocol_bounds` |
| Relative cwd, shared exclusive output, stdin, native/Lua/subprocess separation | `cwd_relative_shared_exclusive_permissions_stdin_native_subprocess` |
| Umask, separate outputs, actual device defaults | `umask_defaults_and_distinct_outputs` |
| Exec/cwd/open failures, retained files, no truncation of existing file | `exec_cwd_open_failures_and_retained_artifact` plus shared-output group |
| Blocked FIFO while second worker executes, timeout, known path evidence | `fifo_blocked_startup_second_worker_useful_timeout_partial_paths` |
| Death after creation before reporting, honest incompleteness | `death_between_create_and_report_is_honestly_incomplete` |
| Malformed/partial handshake, death before ready | `partial_frames_death_and_invalid_handshake` |
| Fragmentation, partial-record timeout, explicit abort and late ready | `fragmented_ready_partial_record_timeout_and_abort_late_ready` |
| Stale generations, unknown/duplicate replies, corrupt worker disposal | `unknown_stale_duplicate_records_dispose_worker`, `duplicate_result_disposes_without_second_completion` |
| Oversized incoming bounded frame; fragmented result | `oversized_transport_frame_disposal_and_fragmented_result` |
| Independent exit detection despite a live inherited writer | `independent_exit_monitor_with_descendant_channel_writer` |
| Intended control CLOEXEC and unrelated descriptor closure | `control_cloexec_and_unrelated_inherited_descriptor_closed` |
| Backpressured command transport cannot block useful second worker | `bounded_nonblocking_write_and_drain_second_worker` |

## Later units are not accepted here

This is not the public session manager. U5 must own sessions, waiters, retained
single-consumer results and response commits. U6 must integrate authoritative
execution deadlines, cancellation, full exit/result races, nonblocking cleanup
fallback/removal and shutdown lifecycle. Current `shutdown` is the provisional
bounded confirmed-reap test/owner cleanup (returns an explicit unconfirmed error,
never pretends kill means reap). Worker objects remain owned by the supervisor;
U5/U6 must remove them according to public lifecycle, not expose them as history.
U7 must couple frame/payload/output limits and enforce global fairness/admission;
this implementation bounds per-worker work, not aggregate manager budgets.
Descendant containment is only a test watchdog facility, not a runtime sandbox.
Installed-package path resolution remains U9. No U5–U7/U9 acceptance is claimed.
