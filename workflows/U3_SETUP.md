# U3 local qualification setup

Run from the checkout. Requires Lua 5.4 interpreter/headers, compiler, LuaRocks
and Python 3. Disposable command work belongs beneath the caller's card work
root; the ignored `.luarocks` tree is the reusable guest-local dependency install.
No global installation, host configuration change or privileged command is needed.

```sh
PROJECT="$PWD"
mkdir -p "$SAIVAGE_CARD_WORK_ROOT/u3-build"
cd "$SAIVAGE_CARD_WORK_ROOT/u3-build"
luarocks --lua-version=5.4 --tree="$PROJECT/.luarocks" install bit32 5.3.5.1-1
luarocks --lua-version=5.4 --tree="$PROJECT/.luarocks" install luaposix 36.3-1
cd "$PROJECT"
eval "$(luarocks --lua-version=5.4 --tree="$PROJECT/.luarocks" path)"
python3 tests/u3_posix.py
```

The driver supplies explicit absolute checkout `?.lua` and `?/init.lua` paths to
both the parent and exec child; native paths come from LuaRocks. It intentionally
checks both absolute interpreter exec and `PATH` search for `lua5.4`. Do not treat
this checkout setup as U9 installed-package validation. See `docs/U3_EVIDENCE.md`
for binding behavior, packaging handoff and the Linux-only observation in this
qualification fixture. `python3 tests/u3_posix.py` enforces a 20-second process-group
watchdog; the Lua fixture also owns/cleans descriptors and reaps its children.
