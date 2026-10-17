# U9 installed release evidence

Baseline: `1877675` (U8). Local candidate **0.1.0-1**, no publication or push.
Installation/adapter/trust/configuration/output/lifecycle instructions:
[RELEASE.md](RELEASE.md). This increment adds packaging, not a new runtime or
alternate evaluator. All 18 Lua modules are explicitly installed, including
worker entrypoints and schemas. No source-relative path workaround was added.

## Reproduction commands and versions

```sh
sh tests/u9_installed.sh
```

Run from checkout with `SAIVAGE_CARD_WORK_ROOT` supplied. The script refuses an
already populated target, installs luaposix **36.3-1** and transitive bit32
**5.3.5.1-1** into a new tree, compiles the C host, then changes to an empty outside
cwd. It unsets inherited generic/versioned Lua paths and supplies **only** the
new installation's module paths. It loads worker and handler entrypoints, runs
the CLI and digest-checked official-schema U8 external suite and C embedding
fixture. It creates jsonschema **4.19.2** venv; Python **3.12.3**, LuaRocks **3.8.0**,
Lua **5.4.6**, pkg-config Lua **5.4.6**, GCC/cc from container were used.

Focused native host command:

```sh
cc -Wall -Wextra -Werror tests/u9_host.c -o "$SAIVAGE_CARD_WORK_ROOT/u9-release/host" \
  $(pkg-config --cflags --libs lua5.4) -pthread
# Set installation-only LUA_PATH; LUA_CPATH='' (native imports disabled).
"$SAIVAGE_CARD_WORK_ROOT/u9-release/host" tests/u9_host.lua
```

C host owns `luaL_newstate`, `luaL_openlibs`, C API registration, a live `FILE*`
and final `lua_close`/`fclose`. API asserts exact state pointer and
`pthread_equal` with invoking thread. Handler never creates a second state or
thread (independent source inspection: only blocking Lua handler and evaluator).
Host globals mutate 10 -> 110 via native API. Close output and successful flush
precede parent assertions; state/handle remain usable. Buffered complete execute
is replayed by parent to 111, partial JSON is completed/decoded; parent then
chooses reset and interpreter shutdown. Package-loaded assertions reject manager,
worker and POSIX imports. This is evidence for this small host, not arbitrary
embedding systems. The test adapter is memory-backed dedicated protocol IO;
U8's real separate pipe-FD fixture additionally establishes actual pipe IO.

Initial host test failed `(null)` because its assertion propagated codec's table
error: the **test's** partial JSON continuation omitted the `"2.0"` value.
Diagnostic xpcall exposed `expected comma at byte 17`; corrected continuation
passes. No product lifecycle semantics changed to accommodate it.

## Regression commands

After selecting the installed 5.4 tree with `luarocks path`, ran every standalone
Lua test except adapter entrypoints, externally driven `*process.lua` fixtures
and the explicitly retained coupled-default red. Explicit loop selection:

```sh
for t in tests/u1*.lua tests/u2.lua tests/u2_review*.lua tests/u4_error*.lua \
 tests/u4_review*.lua tests/u5.lua tests/u6_deadlines_red.lua tests/u6_ordering.lua \
 tests/u6_policy.lua tests/u7*.lua; do
 case "$t" in *process.lua|*coupled_defaults_red.lua) continue;; esac
 lua5.4 "$t" # statuses individually recorded, any failure fails aggregate
 done
for t in tests/u2_live.py tests/u3_posix.py tests/u4_presence.py tests/u4_process.py \
 tests/u5_presence.py tests/u5_process.py tests/u6_process.py tests/u7_process.py; do
 "$PY" "$t"
done
"$PY" docs/check_contracts.py
```

Historical tests named `*_red` are not omitted simply for their names. The only
normative deliberately failing row is `u7_coupled_defaults_red.lua`.

Newer available stable target was built locally, without system installation:

```sh
W="$SAIVAGE_CARD_WORK_ROOT/u9-release"
curl -fLsS https://www.lua.org/ftp/lua-5.5.0.tar.gz -o "$W/lua55/source.tar.gz"
tar -xzf "$W/lua55/source.tar.gz" -C "$W/lua55"
make -C "$W/lua55/lua-5.5.0" -j2 linux
```

Lua **5.5.0** core/handler and pure manager policy tests were run with source
LUA_PATH, empty LUA_CPATH, same loop above. Native-dependent tests
`u4_error_drain.lua`, `u6_ordering.lua`, `u7_frame_budgets.lua`
fail to import posix.unistd; **not passes**. Pinned luaposix 36.3 declares
`lua >= 5.1, < 5.5`; no cross-ABI loading or silent pin upgrade attempted.
5.5 native C host independently compiled against 5.5 static lib and passed.
5.5 standalone manager/full package is unavailable under that required dependency
constraint; its real limitation does not contaminate pure-Lua handler support.

## Exhaustive acceptance traceability

Each numbered SPEC §8 criterion has a named executable witness. `u8_live.py`
group names are listed in [U8_EVIDENCE](U8_EVIDENCE.md) and rerun installed here;
prior U8 results are not substituted for installed evidence.

| SPEC §8 | Named tests / assertions |
|---|---|
| 1 persistence | u1.lua `persistent_globals_functions_chunk_locals`; u8 normative persistence |
| 2 returns/capture | u1.lua `explicit_return_count_and_nil_positions`; u8 normative capture/output isolation |
| 3 recoverable errors | u1.lua `errors_recover_side_effects_once`; u8 normative errors |
| 4 native embedding | u9_host.c/u9_host.lua host_api/state mutation |
| 5 no automatic teardown | u9_host.lua close reason, live handle/global after serve |
| 6 parent reset/shutdown | u9_host.lua reset; u9_host.c parent lua_close/fclose |
| 7 independent workers | u3_posix.py, u5_process.py; u8 explicit persistence/kill/fresh allocation |
| 8 invoking thread | u9_host.c exact state/thread assertions; handler source inspection |
| 9 long execution | u8 async/wait groups; RELEASE lifecycle limitations |
| 10 protocol/stdio isolation | u8 normative capture/output isolation and output file group |
| 11 multiplex/correlation | u8 async out-of-order fast/slow session group |
| 12 os.exit | u8 cancellation/hard deadline/worker exit group; u6_process.py |
| 13 hard/stale deadlines | u6_policy.lua, u6_ordering.lua, u6_process.py; u8 deadline group |
| 14 null/zero/positive wait | u5.lua/u5_process.py; u8 finite_wait group |
| 15 async retention | u8 normative async/poll/single consumer group |
| 16 one terminal consumer | u5.lua/u5_process.py; u8 success/error two waiters |
| 17 kill states/idempotence | u6_policy.lua/u6_process.py; u8 active kill/cancellation |
| 18 implicit allocation | u8 normative null allocation; u5_process.py |
| 19 list state/nonconsumption | u5.lua/u5_process.py; u8 list under 256 saturation |
| 20 argument/null mapping | u1.lua `null_varargs_fresh_tables_and_empty_mapping`; u2_review_argument_matrix.lua |
| 21 errors vs fatal workers | u4_error_contract.lua/u4_review_malformed_error.lua; u8 worker exit |
| 22 close lifecycle | u2.lua, u2_live.py; u9 host close ack before cleanup |
| 23 handoff order/tail | u9_host.lua complete replay/partial completion; u8 dedicated pipe fixture |
| 24 safe numbers | u1.lua `numeric_lexical_safe_boundaries`; u2_review_argument_matrix.lua |

| SPEC §14.8 | Named tests / status |
|---|---|
| 1 blocked startup + partial paths | u3_posix.py; u8 blocked FIFO/create cancellation/output group |
| 2 exit/result/deadline ordering | u4_error_drain.lua; u6_ordering.lua, u6_process.py |
| 3 successful/failed waiter race | u5.lua/u5_process.py; u8 async single consumer |
| 4 saturated reserved control | u7_admission.lua/u7_pending_ownership.lua; u8 external_256_wait_saturation_limit_ping_list_reserved_kill |
| 5 escaping/duplicate maximum | u7_encoding_red.lua/u7_frame_budgets.lua/u7_max_id.lua pass bounded cases; **u7_coupled_defaults_red.lua FAIL, unresolved owner decision** |
| 6 atomic conversion/pointers | u1.lua `rfc6901_pointers`, `hostile_metamethods_and_arbitrary_thrown_values`, `unsupported_returns_and_shapes_no_partial_values` |
| 7 disconnect all phases | u7_transport_process.lua via u7_process.py; u8 disconnect output group |
| 8 unreapable cleanup honesty | u6_policy.lua/u6_process.py unconfirmed-exit branch |
| 9 exclusive/cwd/shared files | u3_posix.py; u8 explicit_relative_shared_output_exclusive_creation... |
| 10 no implicit capture | u1.lua/u2.lua; u8 normative capture/output isolation |

**Unresolved, never waived:** legal request/value each 16777216 requires
67109058 response bytes, bound 67108864, **194-byte contradiction**. Preserved
`lua5.4 tests/u7_coupled_defaults_red.lua` fails. A small limit_exceeded response
is not successful delivery. Full project/U9 acceptance is not claimed while this
row is red. Independent packaging/embedding release work remains useful for a
parent-coordinated U10 trial; this change makes no U10 configuration changes.

## Completed outcomes and durable logs

- Clean installation reproducer `sh tests/u9_installed.sh`: **exit 0**; all ten
  external live groups pass, native host passes and installed modules load.
  Primary output: `work:///cards/card-c-d-b/processes/proc-cf27ef26e014/stdout.log`.
- Independent initial installation/live/native run: **exit 0**,
  `work:///cards/card-c-d-b/processes/proc-7be5ff12ac49/stdout.log`.
- Full 5.4 core/direct/policy/real-process regression command: **exit 0**;
  every individually recorded EXIT is 0. U3 7 capability groups, U4 15 process
  groups, U5 28 committed schema-valid responses, U6 21, U7 real-process watchdog
  groups including 20MiB configured and 16MiB default escaped payload delivery.
  `work:///cards/card-c-d-b/processes/proc-846e2a8226fa/stdout.log`.
  Checker stderr: PASS **14 schemas, 7 official MCP Tools, 2 discovery results,
  23 examples, 125 regression cases**.
- Lua 5.5 loop: **aggregate exit 1**, exactly the three native-import failures
  named above; remaining selected standalone tests and native host pass.
  `work:///cards/card-c-d-b/processes/proc-a9c88fead4e3/stdout.log` and
  `work:///cards/card-c-d-b/processes/proc-a9c88fead4e3/stderr.log`.
- Actual 5.5 LuaRocks attempts also uncover **LuaRocks 3.8.0 header detection
  incompatibility**: initial `--lua-dir` fails to find headers; explicit
  `LUA_INCDIR` then fails header version detection because 5.5 computes
  LUA_VERSION_NUM instead of a literal. Neither attempt reached dependency
  resolution. The independent installed luaposix rockspec's `<5.5` constraint
  remains a second explicit blocker. No claim of a successful 5.5 install.
  `work:///cards/card-c-d-b/processes/proc-5807bd520b7a/stderr.log`,
  `work:///cards/card-c-d-b/processes/proc-6026f10235eb/stderr.log`.
- Installed original `u8_stdio_red.py` probe passes external initialization.
  Subsequent lint in that diagnostic failed because installation-only LUA_PATH
  hid LuaRocks' own Lua 5.1 modules; rerun lint with normal tool environment,
  not by adding checkout paths to runtime. This was a validation-command
  environment error, not a package runtime failure.

No runtime source behavior was modified. Branch review: handler paths retain
read/write/flush progress/error handling, close ack-before-return, failed ack,
EOF/transport/handler reasons and ordered pending handoff; manager retains
startup/exec/exit/disposal ordering. Existing affected-path tests rerun those
branches, rather than repairing symptoms with checkout-relative path injection.

Final manifest lint required a license field; recorded `Proprietary`, avoiding
an invented open-source grant. `luarocks lint` then passes. Reinstalled final
manifest into a third empty tree and reran the complete installed reproducer:
**exit 0**, all ten external groups plus native host and module resolution pass.
Log: `work:///cards/card-c-d-b/processes/proc-626ebb98b7c3/stdout.log`.
Compiler: **Ubuntu cc/GCC 13.3.0**. Lua 5.5.0 archive SHA256:
`57ccc32bbbd005cab75bcc52444052535af691789dba2b9016d5c50640d68b3d`.
Final preserved U7 measurement still fails internally with exit **1**:
`work:///cards/card-c-d-b/processes/proc-9f882cfd3928/stdout.log` and stderr.log;
the diagnostic wrapper exits 0 only because it asserts that known exit 1.
