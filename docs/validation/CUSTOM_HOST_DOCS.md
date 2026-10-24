# Custom-host documentation validation

Documentation input: production `46798f983f811f02ca0534670aca5ab8f3d6fbc7`.
Public content is allowlisted by `docs/build_website.py`; this work document is
not a download or navigation target. Native final acceptance is separate and
incomplete. This is local documentation author verification, not independent
runtime approval.

## Reproduce locally

Use a purpose-named disposable directory as `W`; in a card command use
`W="$SAIVAGE_CARD_WORK_ROOT/custom-host-docs"`. From the checkout root:

```sh
python3 -m venv "$W/venv"
"$W/venv/bin/pip" install -r requirements-docs.txt
"$W/venv/bin/python" docs/check_contracts.py
"$W/venv/bin/python" tests/website_examples.py
"$W/venv/bin/python" tests/website_source_links.py
"$W/venv/bin/python" docs/build_website.py --work-dir "$W/build"
PLAYWRIGHT_BROWSERS_PATH="$W/browsers" "$W/venv/bin/python" -m playwright install chromium
PLAYWRIGHT_BROWSERS_PATH="$W/browsers" "$W/venv/bin/python" tests/website_browser.py
"$W/venv/bin/python" tests/website_red.py
```

Browser execution requires platform libraries. Here they were extracted locally
from Ubuntu noble packages (no system installation) into `W/browser-libs/root`;
`LD_LIBRARY_PATH="$W/browser-libs/root/usr/lib/x86_64-linux-gnu"` was supplied.
Packages: libnspr4, libnss3 (2:3.98-1build1), libatk1.0-0t64,
libatk-bridge2.0-0t64, libatspi2.0-0t64, libxcomposite1, libxdamage1,
libxfixes3, libxrandr2, libgbm1, libxkbcommon0, libasound2t64, libxi6,
libxrender1, libdrm2. The default indexed libnss3 update URL returned 404;
base noble version was available. Chromium 145.0.7632.6 / Playwright 1.58.0
passed desktop and mobile checks, including the custom-host page, navigation,
keyboard and overflow. Before local setup, missing browser executable and then
missing libnspr4 prevented launching; these were environment failures, not passes.

## Installed examples and pure-module recipe

Normal local-source install, not deps-mode-none:

```sh
mkdir -p "$SAIVAGE_CARD_WORK_ROOT/u11-installed"
luarocks --lua-version=5.4 --tree="$SAIVAGE_CARD_WORK_ROOT/u11-installed/rocks" make lua-repl-mcp-0.1.0-1.rockspec
ulimit -n 256
"$W/venv/bin/python" tests/website_installed.py
```

Lua 5.4.6, LuaRocks 3.8.0, luaposix 36.3-1 and bit32 5.3.5.1-1.
Byte identity for installed production modules passed. Both human and exact AI
guide first-use examples passed actual installed discovery/input/output schemas,
first result, state reuse, consumption, ordinary runtime/conversion recovery,
asynchronous polling and confirmed kill. The test cwd is a sibling disposable
child **inside the checkout filesystem**, not literal outside-checkout acceptance.

The exact copy loop in `site-docs/custom-host.md` was executed into
`W/pure-modules`. With only its `?.lua` and `?/init.lua` in LUA_PATH and empty
LUA_CPATH, `tests/u14_session.lua` and `tests/u14_session_diagnostic_red.lua`
passed. The same tests passed against installation-only module paths. These
exercise pure borrowed I/O/bootstrap, same-state once-only, partial writes,
buffered stopping, EOF and all four diagnostic boundaries. They do not validate
a native adapter or take over the independent native acceptance campaign.

## Public contracts and scope

Contract checker passed fourteen standalone schemas, seven official MCP Tools,
two discovery results, 25 JSON examples and 136 regression cases. Website
argument checker passed nine blocks, including custom explicit creation and
execute; source link/fragment/relocation checks had zero missing destinations.
Two strict builds were byte-deterministic; audit checked 11 HTML pages,
337 local links/assets/fragments, exact schema download, 11 allowlisted inputs,
35 artifacts and public boundary. Sources were unchanged by staging. Focused
historical website regression had zero gaps / 11 assertions.

The example executable, flags, host_add API and filesystem paths are explicitly
host-supplied placeholders. No new claim of a generic native adapter or native
host execution is inferred from schema validity. Existing runtime peer evidence
and remaining acceptance qualifications are summarized in the card status,
not embedded in public pages. No production modules, engineering specification,
license, publication or service configuration were changed.
