-- Independent U12 audit: completion must not change merely because relay stalls.
local x=require('lua_repl_mcp.worker_posix')
local b=require('lua_repl_mcp.guardian').new{}
local m=require('lua_repl_mcp.manager').new{supervisor=b}
local function take(r)
 local endat=x.now()+8
 repeat
  local v=m:commit(r,function() return true end)
  if v then return v end
  m:step(5)
  assert(x.now()<endat,'manager response watchdog')
 until false
end
local ok,err=pcall(function()
 local id=take(m:accept('session_create',{})).session_id
 local r=m:accept('session_execute',{
  session_id=id,code='return string.rep("x",1048576)',
  execution_timeout_ms=2000,wait_timeout_ms=require('lua_repl_mcp').null,
 })
 -- Flush only backend: guardian receives execute, but manager cannot consume
 -- the full reply during the deliberate pause. An external watchdog bounds
 -- this process and its guardian/worker even if an internal assertion fails.
 local wire=require('lua_repl_mcp.guardian_channel')
 local sent_by=x.now()+8
 repeat
  b:step(0)
  assert(x.now()<sent_by,'execute flush watchdog')
 until #b.commands==0 and not wire.busy(b.channel)
 local deadline=r.execution.deadline
 x.p.poll({},2500)
 local v=take(r)
 local completed=r.session.worker.result_at
 print('OBSERVE response_status='..tostring(v.status)..
  ' error='..tostring(v.error and v.error.code))
 print('OBSERVE guardian_completion='..tostring(completed)..
  ' deadline='..tostring(deadline))
 assert(completed and completed<deadline,'fixture did not complete before deadline')
 assert(v.status=='completed','pre-deadline completion changed by relay delay')
 assert(v.values and #v.values[1]==1048576,'completed payload changed')
end)
-- Every assertion, including setup/barrier failures, converges on cleanup.
local clean,why=pcall(function() assert(b:shutdown(),'guardian cleanup unconfirmed') end)
assert(ok,err) -- Preserve the original failure if cleanup also fails.
assert(clean,why)
print('PASS pre_deadline_completion_survives_delayed_guardian_relay')
