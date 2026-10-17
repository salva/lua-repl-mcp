# U11 local website validation

## Scope and baseline

Implemented against accepted U12 `0ea8bdd`, without runtime/CLI/rockspec changes.
This is local static documentation validation, not publication or independent
review. No push, publishing configuration, shared-runtime restart or host
configuration change was performed. `https://example.invalid/lua-repl-mcp/` in
MkDocs is an intentionally non-live project-prefix test origin.

The original red check found eight missing-deliverable/boundary gaps and three
already-satisfied checks. Its executable regression is `tests/website_red.py`.
The repair is the authored `site-docs/` guide, pinned MkDocs build and read-only
allowlist staging, plus installed/browser regression coverage—not runtime patches.

## Changes and authority handling

Seven task-oriented pages cover purpose/design/features, interface selection,
installation/first result, persisted state, manager tasks, embedding, data/errors,
operations and functional reference. README links the site sources and retains
the exact LLM guide link. That guide is staged unmodified. The schema download
is byte-identical to the checked-in authoritative schema. No SPEC, work plan,
work instructions, deployment/integration/evidence/conversation/automation
material is staged. RELEASE is now functional package guidance; its complete
pre-U11 contents are retained in `RELEASE_PRE_U11.md` in this evidence directory
and verified byte-identical against `git show 0ea8bdd:docs/RELEASE.md`.

Two explicit public-source editorial changes are not normative contract changes:
`docs/MCP_EXAMPLES.md` replaces its work-SPEC introduction with protocol context
and `/work/project` illustrations with `/example/project`;
`docs/schemas/api.json` replaces the SPEC filename in `$comment` with the warning
that runtime semantics still apply and schemas alone do not execute code.
The latter is deliberately disclosed: the authoritative source was edited,
not secretly filtered while staging. Definitions, constraints and runtime are
unchanged; the full contract validator passes. Reference prose explains behavior
without duplicating a divergent normative SPEC. `tests/docs_consumer.py` only
changes disposable-work location to card-local storage.

## Environment and reproducible commands

Observed Python 3.12.3, Lua 5.4.6, LuaRocks 3.8.0; manager dependency luaposix
36.3-1 (with bit32 5.3.5.1-1). `requirements-docs.txt` pins all installed Python
packages, including MkDocs 1.6.1, jsonschema 4.19.2 and Playwright 1.58.0.
Actual browser: Chromium 145.0.7632.6 (Playwright revision 1208).
Commands below run from repository root in a card activation. `$SAIVAGE_CARD_WORK_ROOT`
is the framework-provided ignored scratch root; do not substitute a sibling tree.

```sh
set -e
W="$SAIVAGE_CARD_WORK_ROOT"
mkdir -p "$W/u11-fresh" "$W/u11-installed/outside" "$W/u11-browser/temp"
python3 -m venv "$W/u11-fresh/venv"
P="$W/u11-fresh/venv/bin/python"
"$P" -m pip install -r requirements-docs.txt
"$P" -m pip check
"$P" docs/build_website.py --work-dir "$W/u11-fresh/build"
"$P" docs/check_contracts.py
"$P" tests/docs_consumer.py
"$P" tests/website_examples.py
# Use a new empty rocks tree for a fresh installation qualification:
luarocks --lua-version=5.4 --tree="$W/u11-installed/rocks" make lua-repl-mcp-0.1.0-1.rockspec
"$P" tests/website_installed.py
PLAYWRIGHT_BROWSERS_PATH="$W/u11-build/browsers" "$P" -m playwright install chromium
# Browser command below; dependency fallback is described next.
TMPDIR="$W/u11-browser/temp" \
PLAYWRIGHT_BROWSERS_PATH="$W/u11-build/browsers" \
LD_LIBRARY_PATH="$W/u11-browser-deps/root/usr/lib/x86_64-linux-gnu" \
"$P" tests/website_browser.py
python3 tests/website_red.py
git diff --check
```

No system browser was installed. Initial Chromium launch exited 127 for missing
`libnspr4.so`. Dependencies were downloaded and extracted, not host-installed:

```sh
mkdir -p "$W/u11-browser-deps/root"
cd "$W/u11-browser-deps"
apt-get download libnspr4 libnss3 libatk1.0-0t64 libatk-bridge2.0-0t64 \
  libatspi2.0-0t64 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
  libxkbcommon0 libgbm1 libasound2t64 libcups2t64 libxi6 libxrender1 \
  libdrm2 libdrm-common
for deb in ./*.deb; do dpkg-deb -x "$deb" root; done
```

These distribution packages are environment bootstrap, not pinned website
inputs. Browser launch subsequently succeeded using only the local extraction
and the preexisting container libraries. Downloaded package filenames and
`download.log` remain in that scratch directory. Initial dependency commands
were sequential and did not themselves prove each download succeeded; actual
successful browser launches establish availability of the needed libraries.

## Executed evidence

A second new virtualenv `u11-fresh/venv` installed the complete pinned requirements
(`u11-fresh/install.log`). Fresh strict builds, not only the earlier development
venv, passed. Final build/browser process `proc-75d738c5b6be` exited 0:

- Both strict clean MkDocs builds completed without warnings.
- Exactly 10 explicitly allowed source files staged; source hashes unchanged
  during build. Two complete output manifests matched: 34 artifact files.
  `SOURCE_DATE_EPOCH=0` fixes bundled-theme build timestamps, not a hash exclusion.
- 10 HTML pages; 286 local links/assets/fragments checked at `/lua-repl-mcp/`.
  Schema download identity checked. Staging closure excludes the rest of the
  repository by construction. Textual HTML/JSON/XML/Markdown/text/JS/CSS/SVG
  artifacts scanned for work material and local machine paths. Single linked
  attribution asserted once in README and once on site home, absent elsewhere;
  no attribution footer. Bundled Bootstrap `card-*` selectors are not work-card IDs.
- Actual Chromium passed desktop 1440×1000 and mobile 390×844 visits to home,
  install, manager and embedding. Checks cover h1, page/container overflow,
  confined code blocks, HTTP errors, link navigation and keyboard Tab/Enter
  reachability of installation (mobile menu activated with Enter).

Browser screenshots: `$W/u11-browser/{desktop,mobile}-{home,getting-started,manager,embedding}.png`
(eight full-page PNGs). Desktop home and mobile getting-started were additionally
viewed via image tooling from ignored `.cache/u11-screenshots/` copies: readable
hierarchy/navigation and contained code blocks; mobile stacked content and
collapsed navigation; no page-wide horizontal overflow observed. This is a smoke
check, not a general accessibility or every-browser certification.

`docs/check_contracts.py`: 14 standalone schemas, 7 official MCP Tools,
2 discovery results, 23 examples, 125 regression cases passed.
`tests/docs_consumer.py`: all three LLM-guide argument blocks validated and exact
pure-Lua copy/module-path adapter recipe initialized/executed/closed over live
pipes with native imports unavailable. It preserves dedicated handles,
plain-function calls and progress-safe `read(1)`, including parent handoff.
`tests/website_examples.py`: all seven authored website JSON tool arguments
validated; actual Lua resource/admission defaults asserted against displayed
values. Wait default is also covered by authoritative schemas/contracts;
lifecycle timings are aligned with accepted U12 evidence, not requalified by
this documentation-only operation.

`tests/website_installed.py`: separate human and LLM journeys run the installed
executable from an outside directory with installation-only Lua paths. Installed
modules are byte-compared to source. Initialize/discover all five manager tools;
validate calls and replies against discovered schemas; execute each guide's
first result (human 42, LLM 2), persisted state and confirmed kill. Also exercised
consumed-result errors, runtime error with retained side effects, conversion
error without session loss, async execution and subsequent polling. Complete
frames and eight-second watchdogs prevent hangs. The first fresh LuaRocks
installation compiled luaposix and bit32; its full install process output is
retained under the card process artifacts (`proc-7b5540819dc3`).

Build manifest: `$W/u11-fresh/build/manifest.json`; staged files and both outputs
are adjacent. Ignored final artifact is repository `site/`. This report and all
other work evidence remain outside the staging allowlist.

## Retained failed hypotheses and corrections

- Initial boundary scan rejected `/work/project` and SPEC comments in selected
  public sources. Applied the disclosed editorial source changes above rather
  than publishing machine paths or staging the SPEC.
- Strict builds initially differed due to the theme's Build Date UTC. Setting
  reproducible source epoch made complete manifests equal.
- Bundled 404 references `/lua-repl-mcp/img/favicon.ico`; auditor initially treated
  that as outside output. Corrected project-prefix resolution, retaining path
  containment and target-existence checks.
- Expanded CSS scan initially mistook Bootstrap `.card-*` component selectors
  for work-card identifiers (`proc-f3204585afd1`, exit 1). Retained every other
  textual exclusion and limited that identifier rule to non-CSS/JS content.
- An immediate keyboard post-Enter URL assertion raced browser navigation;
  changed to assert link reachability and wait for the target URL. Strengthened
  mobile to assert the same success, not merely traverse links.
- No earlier command's later successful sequential step is treated as proof of
  a failed preceding build. Final build/browser rerun is explicitly exit 0.

## Final focused regression

Process `proc-f1448f3b7292` exited 0: pinned-environment `pip check` reported no
broken requirements; `python3 tests/website_red.py` reported **0 gaps, 11 satisfied
focused checks**; `git diff --check` passed. Process `proc-62efe9e9bf43` also exited
0 with the contract, pure-Lua, website-default and both installed journeys above;
the preserved RELEASE byte comparison passed in that same fail-fast command.

## Limits

No whole U9/U12 runtime requalification, public deployment, remote registry
availability, broad OS certification or independent review is claimed. Runtime
files are unchanged. Installed manager, pure-Lua adapter, strict/deterministic
build, project-prefix/static boundary and real browser smoke are distinct
executed checks; JSON validity alone is not substituted for those journeys.
