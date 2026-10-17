-- Real guardian encoder barrier: parent observes an encoding checkpoint,
-- then cancels while execution has not been dispatched to the worker.
local x=require('lua_repl_mcp.worker_posix')
local S=require('lua_repl_mcp.worker_supervisor')
local G=require('lua_repl_mcp.guardian')
local M=require('lua_repl_mcp.manager')
local c=require('lua_repl_mcp.codec')
local rd,wr=assert(x.u.pipe()); x.nonblock(rd)
local encode=c.encode
c.encode=function(value,options)
 if value.items and value.items[1] and value.items[1].result and options and options.checkpoint then
  local checkpoint=options.checkpoint; local marked=false
  local opts={}; for k,v in pairs(options) do opts[k]=v end
  opts.checkpoint=function()
   if not marked then assert(x.u.write(wr,'p')); marked=true end
   checkpoint()
  end
  return encode(value,opts)
 end
 return encode(value,options)
end
-- Guardian close sweep closes unrelated FDs, so preserve the private barrier
-- only in this test child's sweep, never in product worker inheritance.
local close_except=x.close_except
x.close_except=function(a,b,d)
 local n=assert(x.u.sysconf(x.u._SC_OPEN_MAX))
 for fd=3,n-1 do if fd~=a and fd~=b and fd~=d and fd~=wr then x.u.close(fd) end end
end
local b=G.new{}; local m=M.new{supervisor=b}
x.close_except=close_except; c.encode=encode; x.u.close(wr)
local function take(r)
 local deadline=x.now()+15
 repeat local v=m:commit(r,function() return true end); if v then return v end; m:step(0) until x.now()>=deadline
 error('commit watchdog')
end
local ok,err=pcall(function()
 local id=take(m:accept('session_create',{})).session_id
 local args=c.array{}
 local r=m:accept('session_execute',{session_id=id,code='return string.rep(string.char(0),1048576)',args=args})
 local deadline=x.now()+15
 repeat m:step(0); local v=x.u.read(rd,1); if v=='p' then break end; assert(x.now()<deadline,'checkpoint watchdog') until false
 local kill=take(m:accept('session_kill',{session_id=id}))
 assert(kill.process_exit_confirmed)
 local result=take(r)
 assert(result.status=='failed' and not result.values, 'kill before manager application must suppress result')
 print('PASS real_guardian_independent_kill_during_guardian_result_encoding')
end)
x.u.close(rd); b:shutdown(); assert(ok,err)
