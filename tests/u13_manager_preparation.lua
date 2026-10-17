-- Actual manager synchronous preparation cost vs independently enforced guardian
-- execution deadline/reap. No manager step is permitted inside the measured call.
local x=require('lua_repl_mcp.worker_posix')
local c=require('lua_repl_mcp.codec')
local contracts=require('lua_repl_mcp.contracts')
local b=require('lua_repl_mcp.guardian').new{}
local m=require('lua_repl_mcp.manager').new{supervisor=b}
local function take(r)
 local stop=x.now()+100
 repeat local v=m:commit(r,function() return true end); if v then return v end; m:step(0); assert(x.now()<stop) until false
end
local function read(path)
 local f=io.open(path); if not f then return nil end
 local s=f:read('a'); f:close(); return s
end
local ok,err=pcall(function()
 local id=take(m:accept('session_create',{})).session_id
 local id2=take(m:accept('session_create',{})).session_id
 local children=assert(read('/proc/'..b.guardian_pid..'/task/'..b.guardian_pid..'/children'))
 local identities={}
 for pid in children:gmatch('%d+') do identities[pid]=assert(read('/proc/'..pid..'/stat')) end
 local rd,wr=assert(x.u.pipe())
 local code='local f=assert(io.open("/proc/'..x.u.getpid()..'/fd/'..wr..'","w")); local s=assert(io.open("/proc/self/stat","r")); f:write(s:read("l"):match("^%d+").."\\n"); s:close(); f:flush(); f:close(); while true do end'
 -- Allocate the legal expensive argument before arming the other worker timer.
 local data=c.array{}; for i=1,650000 do data[i]=1e-7 end
 local input={session_id=id2,code='return 73',args=c.array{data},wait_timeout_ms=require('lua_repl_mcp').null}
 assert(#assert(c.encode(input))<=b.limits.input_bytes)
 local active=m:accept('session_execute',{session_id=id,code=code,execution_timeout_ms=500})
 x.nonblock(rd)
 local stop=x.now()+10
 local token=''
 repeat m:step(0); local s=x.u.read(rd,64); if s then token=token..s end; if token:find('\n',1,true) then break end; assert(x.now()<stop) until false
 local expired=assert(token:match('^(%d+)\n')); assert(identities[expired])
 x.u.close(rd); x.u.close(wr)
 local steps=0; local step=m.step
 m.step=function(...) steps=steps+1; return step(...) end
 local validate=contracts.validate; local passes=0; local cost=0
 contracts.validate=function(tool,value,options)
  local start=x.now(); local a,e=validate(tool,value,options)
  if tool=='session_execute' or tool=='repl_execute' then passes=passes+1; cost=cost+x.now()-start end
  return a,e
 end
 local start=x.now()
 local success,result=pcall(m.accept,m,'session_execute',input)
 local elapsed=x.now()-start
 contracts.validate=validate; m.step=step
 assert(success,result); assert(steps==0 and passes==1)
 assert(elapsed>.5,'fixture did not overlap original deadline')
 -- Before ANY manager progress, at least the deadline-owned worker identity
 -- must have disappeared (zombie still present is not success).
 assert(not read('/proc/'..expired..'/stat'),'guardian did not independently reap exact expired worker')
 assert(take(active).error.code=='execution_timeout')
 assert(take(result).values[1]==73)
 assert(take(m:accept('session_kill',{session_id=id2})).process_exit_confirmed)
 print('PASS independent_guardian_deadline_reap_during_manager_preparation passes='..passes..' validation_seconds='..cost..' accept_seconds='..elapsed)
end)
b:shutdown(); assert(ok,err)
