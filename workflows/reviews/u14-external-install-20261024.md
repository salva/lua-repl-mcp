# U14 operator external-install evidence — 2026-10-24

This closes an unavailable execution boundary with actual operator-run tests,
not an acceptance waiver or a change to verifier tool permissions. Independent
verifier and parent still own their acceptance decisions.

## Input and isolation

- Exact input: `cbe1c44dbe05f2b2046dd0f50b74290f84cd7093`.
- Dedicated container: `saivage-lua-repl-mcp`; commands executed as `salva`.
- Guest external root: `/home/salva/tmp/lua-repl-mcp-external-20261024-2004`.
- `source/` is a Git archive, without `.git`, runtime state or credentials.
  All 472 tracked entries matched Git content/symlink targets/executable bits
  before and after tests. Original `/work/lua-repl-mcp` remained unchanged.
- Fresh normal dependency resolution/install into `validation/rocks`, not a
  borrowed project dependency tree. Lua paths contain only this installation;
  versioned path overrides unset. Client/test cwd is `validation/outside`.
- Lua interpreter and embedding ABI:5.4.6; LuaRocks3.8.0. Dependency versions
  and full installation output are retained in `logs/install.log`.

## Commands and outcome

The complete script is `external-check.sh` at the external root. It runs fresh
`luarocks --lua-version=5.4 --tree=... make`, compiles the existing native host
with `cc -Wall -Wextra -Werror` and pkg-config's Lua5.4 flags, then runs:

1. `tests/u14_native_client.py`: PASS actual installed MCP explicit/implicit
   native API, literal argv, cross-chunk state, partial native I/O, once-only
   errors, host continuation, confirmed kill/foreign-C deadline, manager-SIGKILL
   exact native-child disappearance before harness cleanup.
2. `tests/u14_native_wire.py`: PASS buffered stop/close rejects later effects,
   borrowed blocked-read EOF wakeup and host continuation.
3. `tests/u14_native_matrix.lua` under existing containment: PASS all eight
   closed-stdio masks, graceful borrowed return, exec/cwd/stdio failures and
   initialization timeout with exact reap.
4. `tests/u9_suite.py`: PASS **one uninterrupted complete installed driver**,
   all119 enabled manifest fixtures and installed production-module byte identity.
   Final marker `PASS complete_installed_core_handler_manager_suite`.
5. Driver's contract checker:14schemas/7Tools/2discovery/25examples/136regressions PASS.

Original fixture sizes, deadlines, manifest and assertions unchanged. Script
exited0, receipt completed2026-10-24T20:17:32.421343Z. Expected injected guardian
uncertainty diagnostics occur in the passing suite; they are not universal cleanup
guarantees. These are operator-run component/runtime tests, not provider/UI or
documentation-site acceptance, nor proof of historical orphan cleanup.

## Preserved receipts

Guest `result.json`, `source-manifest.json`, `source-verification.json`, script
and `logs/` are retained under the external root. Verifier may inspect these
existing files read-only without creating external disposable work. Host copies
and source-verification receipts are under workspace
`tmp/lua-repl-mcp-block-followup-20261024/`.

SHA-256 of guest log bytes (also copied to host):

| Log | SHA-256 |
| --- | --- |
| complete-suite.log | `a485305f9acb1bb561e45df605c20c909c116933ae5f53a8184860a0a051b21a` |
| install.log | `50e7f15c8e695d7578ee47a7efac4ff77419e239102706eb750f9747fc33751a` |
| native-client.log | `b4f2f0eaa1e711046a96e8ae6a2a04f50a3d641ae0dc20411ad0baa77db0e40a` |
| native-matrix.log | `2121c955dfe9ba8b2c00129dfc8516980fd21a7fd98be143169bb46ae73d7a05` |
| native-wire.log | `a6192ca4081daee8deefb77a3dbbb298ad2d9d7720f943a7089f57c5af107020` |

No production/source/test/schema edits, acceptance relaxation, provider change,
prompt/config change, service restart, reset or publication was performed by
this external test. Separately queued Saivage scratch-contract improvement is
not implemented or deployed by these receipts.
