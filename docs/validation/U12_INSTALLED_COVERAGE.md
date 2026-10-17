# U12 installed lifecycle coverage increment

[[card:card-d-c]], add-coverage node. Runtime remains identical to
459f7fa93b3c956806bbaaa08f82d538eb7d2e98 (af80aa9 relay /9f82e55 EOF fixes).
This increment closes the installed lifecycle harness gap diagnosed in
[U12_RELEASE_DIAGNOSIS.md](U12_RELEASE_DIAGNOSIS.md), not global release acceptance.

## Changes and assertions

- `tests/u12_environment.py`: explicit installed/outside mode shared by lifecycle
  fixtures. Exact installation-only generic paths, absent versioned overrides,
  same-tree CLI and all-module byte identity are required. Matrix Lua processes
  assert server/guardian/channel/supervisor/worker entrypoint resolution before
  spawn. Default checkout mode is preserved.
- `tests/u12_lifecycle_red.py` selects the explicit CLI/cwd; `u12_matrix.py`
  selects the explicit cwd and resolution prelude. No state, ordering, deadline,
  expected status, readiness barrier or containment assertion is weakened.
- `tests/u12_installed_environment.py` rejects six contaminated environment
  variants (default fallback, relative native path, both versioned overrides,
  checkout CLI and checkout cwd) before any tested process starts.
- `tests/u9_suite.py` now includes environment regression, lifecycle probe,
  complementary guardian probe and full28-case matrix under its existing
  fail-fast420s per-driver watchdog. Module identity label no longer hardcodes18.

## Focused executed verification

Reused only the empty-tree installation built during diagnosis; no package source
or dependencies changed. New fixtures and all lifecycle executions are current.
From checkout, with ROOT=$PWD and
W="$SAIVAGE_CARD_WORK_ROOT/u12-release-diagnosis/u9-clean-reproducer":

```sh
unset LUA_PATH_5_4 LUA_CPATH_5_4
export LUA_PATH="$W/rocks/share/lua/5.4/?.lua;$W/rocks/share/lua/5.4/?/init.lua"
export LUA_CPATH="$W/rocks/lib/lua/5.4/?.so"
export U9_INSTALLED_CWD="$W/outside"
export U9_INSTALLED_MODULES="$W/rocks/share/lua/5.4/lua_repl_mcp"
export U12_INSTALLED_CLI="$W/rocks/bin/lua-repl-mcp"
python3 tests/u12_installed_environment.py
cd "$W/outside"
python3 "$ROOT/tests/u12_lifecycle_red.py"
python3 "$ROOT/tests/u12_guardian_process.py"
python3 "$ROOT/tests/u12_matrix.py"
```

Two lifecycle/probe/matrix sequences completed exit0. Final strengthened exact
path assertion sequence: `work:///cards/card-d-c/processes/proc-7b641ae18386/stdout.log`
(read completely), stderr empty. All28 matrix cases pass: INT/TERM/KILL/abrupt
across idle/FIFO startup/pre-exec spawn/infinite/native blocked states; live
subprocess inheritance, guardian-loss fail-closed, repeat signals, EOF and fatal
boundary paths. TERM-ignore disposal20.048s/20.015s. Guardian-loss worker is
explicitly test-contained, not falsely claimed automatically disposed. Six CLI
probe cases observe guardian ownership, expected130/143/-9 statuses and workers
not alive after bound. Only isolated own process groups are contained.

Durable environment-negative fixture executed separately exit0 (all six rows),
plus changed Python AST syntax and `git diff --check` exit0:
`work:///cards/card-d-c/processes/proc-823311ed7c17/stdout.log`.
Initial unstrengthened sequence also passed:
`work:///cards/card-d-c/processes/proc-be9684d27303/stdout.log`.
Lua5.4.6, luaposix36.3-1, bit32 5.3.5.1-1; same installation as diagnosis.

## Remaining acceptance, not waived

Full combined updated driver acceptance is verify-owned, not inferred from this
focused run. Real U10 agent trials still require current returned calls and
interpretation: previous1007245 evidence remains historical. Issue8 remains
filed-not-fixed; unrelated-session loss at client deadline is not a pass.
No real-agent trial, credential copy, shared runtime modification/restart,
host/service/generated-state edit, public-doc rewrite, push or publication in
this increment. No current product defect exposed and no artificial red authored.
