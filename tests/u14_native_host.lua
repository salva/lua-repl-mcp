-- This runs inside the C-owned Lua5.4 state, without native Lua dependencies.
assert(package.loaded['posix.unistd']==nil)
local boot=assert(require('lua_repl_mcp.bootstrap').decode(
 os.getenv('LUA_REPL_MCP_SESSION_FD'),os.getenv('LUA_REPL_MCP_ALLOCATION_GENERATION'),os.getenv('LUA_REPL_MCP_LIMITS')))
local outcome=require('lua_repl_mcp.session').serve({read=native_read,write=native_write,flush=native_flush},
 {allocation_generation=boot.allocation_generation,limits=boot.limits,cwd=assert(host_cwd),stopping=function() return host_stopping end})
assert(package.loaded['posix.unistd']==nil)
assert(outcome.reason=='closed' or outcome.reason=='eof' or outcome.reason=='host_stopping',outcome.reason)
assert(host_api(2)==102)
if host_receipt then
 local f=assert(io.open(host_receipt,'w')); f:write(outcome.reason,':',tostring(host_value)); f:close()
end
