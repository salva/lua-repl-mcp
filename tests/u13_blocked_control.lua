-- Independent control must progress while bulk receive is blocked. Restoring
-- bulk in finally is cleanup only, never the acceptance condition.
local x=require('lua_repl_mcp.worker_posix')
local G=require('lua_repl_mcp.guardian')
local M=require('lua_repl_mcp.manager')
local wire=require('lua_repl_mcp.guardian_channel')
local null=require('lua_repl_mcp').null
local b=G.new{}; local m=M.new{supervisor=b}
local read=x.u.read
local function take(r,seconds)
 local deadline=x.now()+seconds
 repeat
  local v=m:commit(r,function() return true end)
  if v then return v end
  m:step(0)
 until x.now()>=deadline
end
local ok,err=pcall(function()
 local id=assert(take(m:accept('session_create',{}),10)).session_id
 local r=m:accept('session_execute',{session_id=id,code='return string.rep("x",16777212)',wait_timeout_ms=null})
 -- Finish sending execute before withholding the result stream. Current
 -- transport is command/report lockstep, so commands empty is dispatch barrier.
 local deadline=x.now()+10
 repeat b:step(0); assert(x.now()<deadline,'execute dispatch watchdog')
 until #b.commands==0 and not wire.busy(b.channel)
 x.u.read=function(fd,n)
  if fd==b.channel.fd then return nil,'withheld bulk',x.e.EAGAIN end
  return read(fd,n)
 end
 local kill=m:accept('session_kill',{session_id=id})
 local result=take(kill,2)
 print('OBS blocked_bulk_kill_committed='..tostring(result~=nil)..' queued_commands='..#b.commands)
 assert(result and result.status=='killed' and result.process_exit_confirmed,'kill depends on draining bulk result')
end)
x.u.read=read
local clean,why=pcall(function() assert(b:shutdown()) end)
assert(ok,err); assert(clean,why)
print('PASS independent_control_during_blocked_bulk')
