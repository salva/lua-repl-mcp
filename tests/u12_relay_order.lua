-- Real guardian relay ordering, complementary to unchanged independent reproducer.
local G=require('lua_repl_mcp.guardian')
local M=require('lua_repl_mcp.manager')
local x=require('lua_repl_mcp.worker_posix')
local wire=require('lua_repl_mcp.guardian_channel')
local null=require('lua_repl_mcp').null
for _,mode in ipairs{'tiny','partial_backend','accepted_kill','completed_kill','hard_timeout','guardian_loss'} do
 local b=G.new{}; local m=M.new{supervisor=b}
 local function take(r)
  local endat=x.now()+8
  repeat
   local v=m:commit(r,function() return true end)
   if v then return v end
   m:step(5); assert(x.now()<endat,'response watchdog '..mode)
  until false
 end
 local ok,err=pcall(function()
  local id=take(m:accept('session_create',{})).session_id
  local size=mode=='tiny' and 1 or 1048576
  local r=m:accept('session_execute',{session_id=id,
   code=mode=='hard_timeout' and 'while true do end' or 'return string.rep("x",'..size..')',
   execution_timeout_ms=2000,wait_timeout_ms=null})
  local endat=x.now()+8
  repeat b:step(0); assert(x.now()<endat,'flush watchdog')
  until #b.commands==0 and not wire.busy(b.channel)
  local deadline=r.execution.deadline
  if mode=='accepted_kill' then
   -- Manager still regards this generation as active, before report receipt.
   local kill=m:accept('session_kill',{session_id=id})
   assert(r.execution.payload.error.code=='session_killed')
   assert(take(kill).status=='killed')
   local v=take(r); assert(v.status=='failed' and v.error.code=='session_killed')
  elseif mode=='guardian_loss' then
   x.s.kill(b.guardian_pid,x.s.SIGKILL)
   local endat=x.now()+8; local lost=false
   repeat local good,msg=pcall(m.step,m,5)
    if not good then assert(tostring(msg):find('guardian lost',1,true)); lost=true end
    assert(x.now()<endat,'loss watchdog')
   until lost
   assert(b.closed and r.session.worker.process_exit_confirmed==false)
   -- No safe worker PID fallback after guardian loss. Wrapper contains group.
  elseif mode=='completed_kill' then
   local endat=x.now()+8
   repeat m:step(5); assert(x.now()<endat) until r.execution.status=='completed'
   assert(take(m:accept('session_kill',{session_id=id})).status=='killed')
   local v=take(r)
   assert(v.status=='completed' and #v.values[1]==size and not v.session_usable)
  else
   x.p.poll({},2500)
   if mode=='partial_backend' then
    -- One bounded receive turn cannot consume this result. Crossing deadline
    -- during partial private decode must not freeze a stale running mirror.
    local partial_by=x.now()+3
    repeat b:step(0); assert(x.now()<partial_by,'partial report barrier') until #b.channel.input>0
    assert(b.inflight and r.session.worker.state=='running')
    assert(not r.session.worker.failure)
   end
   local v=take(r)
   if mode=='hard_timeout' then
    assert(v.status=='failed' and v.error.code=='execution_timeout' and v.process_exit_confirmed)
   else
    assert(v.status=='completed' and #v.values[1]==size)
    assert(r.execution.completed_at<deadline and r.session.worker.state=='idle')
   end
  end
 end)
 local clean,why=pcall(function() if not b.closed then assert(b:shutdown()) end end)
 assert(ok,err); assert(clean,why)
 print('PASS relay_order_'..mode)
end
