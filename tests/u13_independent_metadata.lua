-- A blocked result relay must not prevent another already admitted worker's
-- execution command or small completion metadata from reaching its guardian.
local G=require('lua_repl_mcp.guardian')
local M=require('lua_repl_mcp.manager')
local x=require('lua_repl_mcp.worker_posix')
local wire=require('lua_repl_mcp.guardian_channel')
local null=require('lua_repl_mcp').null
local b=G.new{}; local m=M.new{supervisor=b}; local read=x.u.read
local function take(r)
 local deadline=x.now()+15
 repeat
  local v=m:commit(r,function() return true end)
  if v then return v end
  m:step(0); assert(x.now()<deadline,'metadata watchdog')
 until false
end
local ok,err=pcall(function()
 local a=take(m:accept('session_create',{})).session_id
 local z=take(m:accept('session_create',{})).session_id
 m:accept('session_execute',{session_id=a,code='return string.rep("x",16777212)',wait_timeout_ms=null})
 local deadline=x.now()+10
 repeat b:step(0); assert(x.now()<deadline) until #b.commands==0 and not wire.busy(b.channel)
 x.u.read=function(fd,n)
  if fd==b.channel.fd then return nil,'blocked bulk',x.e.EAGAIN end
  return read(fd,n)
 end
 local r=m:accept('session_execute',{session_id=z,code='return 73',wait_timeout_ms=null})
 deadline=x.now()+12
 repeat
  m:step(0)
 until r.session.worker.validated_generation==r.session.worker.execution_generation or x.now()>=deadline
 assert(r.session.worker.validated_generation==r.session.worker.execution_generation,
  'second execution/completion metadata depends on draining first bulk result')
 assert(r.execution.status=='running','guardian validation must not imply manager payload application')
 x.u.read=read
 assert(take(r).values[1]==73)
end)
x.u.read=read
local clean,why=pcall(function() assert(b:shutdown()) end)
assert(ok,err); assert(clean,why)
print('PASS command_and_completion_progress_during_blocked_bulk_distinct_application')
