package = "lua-repl-mcp"
version = "0.1.0-1"
source = { url = "file://lua-repl-mcp-0.1.0.tar.gz" }
description = {
  license = "Proprietary",
  summary = "Trusted-code Lua MCP handler and POSIX session manager",
  detailed = "Pure-Lua embedded handler; POSIX standalone workers. Local release candidate; not published.",
}
dependencies = { "lua >= 5.4, < 5.6", "luaposix == 36.3-1" }
build = {
  type = "builtin",
  modules = {
    ["lua_repl_mcp.guardian"] = "lua_repl_mcp/guardian.lua",
    ["lua_repl_mcp.guardian_channel"] = "lua_repl_mcp/guardian_channel.lua",
    ["lua_repl_mcp.client_transport"] = "lua_repl_mcp/client_transport.lua",
    ["lua_repl_mcp.codec"] = "lua_repl_mcp/codec.lua",
    ["lua_repl_mcp.contracts"] = "lua_repl_mcp/contracts.lua",
    ["lua_repl_mcp.direct_schemas"] = "lua_repl_mcp/direct_schemas.lua",
    ["lua_repl_mcp.errors"] = "lua_repl_mcp/errors.lua",
    ["lua_repl_mcp.evaluator"] = "lua_repl_mcp/evaluator.lua",
    ["lua_repl_mcp.framing"] = "lua_repl_mcp/framing.lua",
    ["lua_repl_mcp.handler"] = "lua_repl_mcp/handler.lua",
    ["lua_repl_mcp"] = "lua_repl_mcp/init.lua",
    ["lua_repl_mcp.limits"] = "lua_repl_mcp/limits.lua",
    ["lua_repl_mcp.manager"] = "lua_repl_mcp/manager.lua",
    ["lua_repl_mcp.manager_schemas"] = "lua_repl_mcp/manager_schemas.lua",
    ["lua_repl_mcp.protocol"] = "lua_repl_mcp/protocol.lua",
    ["lua_repl_mcp.session"] = "lua_repl_mcp/session.lua",
    ["lua_repl_mcp.bootstrap"] = "lua_repl_mcp/bootstrap.lua",
    ["lua_repl_mcp.worker_setup"] = "lua_repl_mcp/worker_setup.lua",
    ["lua_repl_mcp.server"] = "lua_repl_mcp/server.lua",
    ["lua_repl_mcp.worker_main"] = "lua_repl_mcp/worker_main.lua",
    ["lua_repl_mcp.worker_posix"] = "lua_repl_mcp/worker_posix.lua",
    ["lua_repl_mcp.worker_protocol"] = "lua_repl_mcp/worker_protocol.lua",
    ["lua_repl_mcp.worker_supervisor"] = "lua_repl_mcp/worker_supervisor.lua",
  },
  install = { bin = { ["lua-repl-mcp"] = "lua-repl-mcp" } },
}
