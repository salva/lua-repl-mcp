# Public reference

## Functional contract

A request executes a complete Lua chunk once, with JSON arguments as varargs.
Explicit returns produce JSON values. Globals persist in the selected worker or
existing host interpreter; locals do not. There is no expression fallback,
automatic output capture, task ID, reset tool or implicit durable storage.

The manager provides `session_create`, `session_list`, `session_execute`,
`session_wait`, `session_kill`. Direct embedding provides `repl_execute`,
`repl_close`. Use [manager tasks](manager.md) for state/consumption semantics,
[embedding](embedding.md) for parent handoff, [data/errors](data-errors.md) for
conversion and [operations](operations.md) for defaults and cleanup.

## Authoritative downloads

- [Tool input/output JSON schemas](../docs/schemas/api.json): all seven tools,
  shared errors and result types. Download/parse as JSON; `$defs` are not URLs.
- [MCP wire examples](../docs/MCP_EXAMPLES.md): initialization, discovery,
  execution, pending results and failures, with expected outcomes.
- [Exact LLM guide](../README-IF-YOR-ARE-AN-AI.md): install, launch and recovery,
  including pure-Lua adapter recipe.

MCP uses newline-delimited JSON-RPC, protocol version `2025-11-25`.
Initialize before discovery; send `notifications/initialized`. Correlate replies
by JSON-RPC ID, not session ID. Read `structuredContent`; compatibility text is
the same payload. Clients may prefix tool names in their UI: use discovery.

## Compatibility

For literal `command`, `--startup-timeout-ms`, the version-1 environment/FD ABI,
`bootstrap.decode` and borrowed `session.serve`, see [custom hosts](custom-host.md).
These use session tools, not the public handler's two tools. Final independent
runtime acceptance of this development candidate remains incomplete.

The local-source package is 0.1.0-1; the verified standalone target uses Linux,
Lua 5.4.6 and luaposix 36.3-1. The pure-Lua handler has separate historical
qualification on Lua 5.5; that does not establish Lua 5.5 native-manager support.
No public registry availability, general OS certification or publication is
implied. Use the local-source install instructions, not an assumed remote URL.

## Local checks and contributions

From a checkout with Python 3 and the pinned documentation dependencies:

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements-docs.txt
.venv/bin/python docs/check_contracts.py
.venv/bin/python docs/build_website.py --work-dir "$PWD/.cache/website"
```

The builder stages only selected user content and checks a strict local build.
Generated `site/` is disposable. No publishing service is needed. For changes,
keep examples aligned with discovered schemas and test actual installed behavior,
not just JSON validity. Submit coherent source changes with regression tests;
do not mix work reports into user navigation or downloads.
