# Qualified acceptance ownership

Run `sh tests/u9_installed.sh` from checkout with `SAIVAGE_CARD_WORK_ROOT`
pointing at disposable card work. It installs into a purpose-named child, then
runs from outside checkout with installation-only Lua paths and byte identity
checks. Reusing an existing install requires explicit `U9_INSTALLED_CWD`,
`U9_INSTALLED_MODULES`, `U12_INSTALLED_CLI`, `LUA_PATH`, `LUA_CPATH`, and invoking
`tests/u9_suite.py` from outside checkout. No default/checkout fallback is allowed.

`containment.py SECONDS COMMAND...` is an external Linux-only test supervisor,
not the product guardian. It owns a dedicated initial fixture process group and
sets PR_SET_CHILD_SUBREAPER before spawning. It observes only its own direct
children and signals through pidfds; adopted escaped-session descendants are
killed/reaped after their parents, never selected by name or stale PID/PGID.
A five-second cleanup observation limit reports failure rather than confirming
an unkillable child. While the fixture runs, the owner nonblockingly waits only
already-exited adoptees, excluding the immediate fixture child whose status is
retained for result capture. This prevents harness-owned zombies from falsely
keeping dead groups present during actual client containment checks. It neither
signals live adoptees nor proves product-owned worker/guardian reap; those
assertions must still precede harness cleanup. Kernel pidfd/subreaper absence returns 125 (blocked), not a
weaker POSIX fallback. SIGTERM/SIGINT to the owner triggers cleanup; SIGKILL of
the external owner itself cannot be recovered by that owner. This is not a
sandbox or a claim about arbitrary hostile same-UID processes.

`enter()` re-execs standalone Python wrappers under that supervisor. Nested
wrappers verify the inherited owner's ancestry and do not create another owner
or session. Local waits still bound individual fixtures; the external owner
survives aggregate/wrapper failure and performs final tree cleanup. A wrapper
must not call `killpg` on the inherited shared group. Its local failure paths
kill/wait the immediate child only, then propagate failure to the owner.

`fixtures.json` explicitly declares Lua fixtures and installed Python wrapper
invocations, their classification, owner, deadline and expected disposition.
`host` entries require their named native/external driver. `native` means native
imports/FDs without a spawned child; `process` means real child ownership. New
Lua files require an explicit manifest update. Historical 64MiB expected red
requires status 1 AND the precise named coupled-default assertion, not arbitrary
nonzero exit. It is not the current 128MiB default expectation. U13 infrastructure
checks are separate from the installed product suite:

```
python3 tests/u13_reproduced.py
python3 tests/u13_containment.py
python3 docs/check_contracts.py
git diff --check
```

Current local Saivage client-component qualification (requires the offline clean
install at `$SAIVAGE_CARD_WORK_ROOT/current-qualification/rocks`):

```
cd "$SAIVAGE_CARD_WORK_ROOT/current-qualification/outside"
python3 /work/lua-repl-mcp/tests/containment.py 100 node /work/lua-repl-mcp/tests/simplicity_client.mjs
```

This explicitly imports the existing local production client, not a protocol
simulator or an authenticated agent/UI session. It uses its own disposable
client root and does not change shared runtime/provider configuration. A real
shell-start barrier precedes active kill. Exited adopted shell children are
waited by the test owner; direct worker/guardian reap remains product-owned.

Fault tests cover aggregate crash, nested-wrapper crash followed by aggregate
timeout, owner signal, TERM-ignore/new-session descendant adoption, immediate
child reaping, partial frame/stall, early EOF and complete frame. AST-based checks
exercise the actual installed-website RPC and pending loop using bounded fake
clocks; no missing environment is substituted by those unit checks. Current
website journeys and product qualification must still run independently.
