# Local-source package 0.1.0-1

Lua REPL MCP provides persistent managed Lua sessions and an independent,
blocking pure-Lua embedded handler. This is trusted arbitrary code execution,
not a sandbox. No public package registry release is claimed. The operator
published a development-candidate repository/site separately; publication is
not release acceptance. U13 findings and final installed/live-client qualification
remain open; historical U1–U12 receipts are not a current no-gap claim.

Start with the [installation and usage guide](../README-IF-YOR-ARE-AN-AI.md).
The manager targets Lua 5.4 on POSIX, with luaposix 36.3-1 and a C compiler
for dependency installation. The embedded handler needs only the documented
pure-Lua modules in a supported Lua host, with dedicated protocol I/O.

Managed sessions are connection-owned, not durable. A POSIX guardian supervises
workers independently of the manager, including manager-only abrupt death.
Graceful shutdown requests bounded cleanup. Disposal retries TERM for 20 seconds,
then KILL for 10 seconds, stopping on confirmed exit; warnings distinguish
unconfirmed cleanup from OS exit. This does not sandbox user code or promise
cleanup of arbitrary subprocess descendants. Embedded hosts retain ownership
of their interpreter, descriptors and shutdown policy.

See [wire examples](MCP_EXAMPLES.md) and [schemas](schemas/api.json) for the
public protocol. Use the installed executable with no arguments and preserve
its LuaRocks environment for worker processes. No publication or license grant
beyond the package metadata is implied.
