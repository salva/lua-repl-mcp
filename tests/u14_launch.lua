-- Run with project Lua paths and luaposix available.
local S=require('lua_repl_mcp.guardian')
local x=require('lua_repl_mcp.worker_posix')
local c=require('lua_repl_mcp.codec')
local script="package.path="..string.format('%q',package.path)..";package.cpath="..string.format('%q',package.cpath)..";host_marker=73;host_argv=arg;require('lua_repl_mcp.worker_main').main()"
local s=S.new()
local function until_(f) local deadline=x.now()+8; repeat s:step(5); if f() then return end until x.now()>deadline; error('deadline') end
local ok,err=xpcall(function()
 local w=s:allocate{command=c.array{'lua5.4','-e',script,'literal a b','$HOME',''}}
 until_(function() return w.state~='starting' end)
 assert(w.state=='idle',tostring(w.failure)..':'..tostring(w.startup_message))
 assert(s:execute(w,{code='host_marker=host_marker+1; return host_marker'}))
 until_(function() return w.state~='running' end)
 assert(w.result and w.result.values[1]==74)
 assert(s:execute(w,{code='return host_marker'}))
 until_(function() return w.state~='running' end)
 assert(w.result.values[1]==74)
 s:abort(w,'session_killed')
 until_(function() return w.state=='dead' end)
 assert(w.process_exit_confirmed)
end,debug.traceback)
assert(s:shutdown())
assert(ok,err)
print('PASS guardian custom argv launch and same-state continuation, exact-child disposal')
