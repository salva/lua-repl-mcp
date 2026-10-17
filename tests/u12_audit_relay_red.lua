-- Independent U12 audit: completion must not change merely because relay stalls.
local x=require('lua_repl_mcp.worker_posix'); local m=require('lua_repl_mcp.manager').new{supervisor=require('lua_repl_mcp.guardian').new{}}
local function take(r)
 local endat=x.now()+8
 repeat local v=m:commit(r,function() return true end); if v then return v end; m:step(5); assert(x.now()<endat) until false
end
local id=take(m:accept('session_create',{})).session_id
local r=m:accept('session_execute',{session_id=id,code='return string.rep("x",1048576)',execution_timeout_ms=2000,wait_timeout_ms=require('lua_repl_mcp').null})
-- Flush only backend: guardian receives execute, manager intentionally cannot consume full reply yet.
local wire=require('lua_repl_mcp.guardian_channel'); local b=m.backend
repeat b:step(0) until #b.commands==0 and not wire.busy(b.channel)
x.p.poll({},2500)
local deadline=r.execution.deadline
local v=take(r)
print(require('lua_repl_mcp.codec').encode(v));
local completed=r.session.worker.result_at
print('guardian completion',completed,'deadline',deadline,'execution failure',r.execution.status); b:shutdown()
assert(completed and completed<deadline,'fixture did not complete before deadline')
assert(v.status=='completed','pre-deadline completion changed by relay delay')
