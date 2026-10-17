-- Focused U6 red checks: authoritative hard deadline and kill cleanup ordering.
local manager=require('lua_repl_mcp.manager')
local null=require('lua_repl_mcp').null
local codec=require('lua_repl_mcp.codec')
local failures=0
local function check(name,ok,detail)
 print((ok and 'PASS ' or 'FAIL ')..name..' '..(detail or ''))
 if not ok then failures=failures+1 end
end
local function fixture()
 local now=0
 local b={clock=function() return now end,cwd='/fixture'}
 function b:allocate() return {state='idle'} end
 function b:execute(w) w.state='running'; return 1 end
 function b:abort(w,cause) w.state='terminating'; w.failure=cause end
 function b:step() end
 local m=manager.new{supervisor=b}
 local cr=m:accept('session_create',{})
 local id=assert(m:commit(cr,function() return true end)).session_id
 local r=m:accept('session_execute',{session_id=id,code='',wait_timeout_ms=null,execution_timeout_ms=10})
 return m,r,r.session,function(t) now=t end
end
for _,case in ipairs({{name='before',time=.009,complete=true},
 {name='exact',time=.010,complete=false},{name='after',time=.011,complete=false}}) do
 local m,r,s,time=fixture()
 time(case.time)
 s.worker.result={status='completed',values=codec.array({42})}; s.worker.state='idle'
 m:step(0)
 local v=m:preview(r)
 if case.complete then
  check('completion_'..case.name,v and v.status=='completed')
 else
  check('completion_'..case.name..'_cannot_win',not(v and v.status=='completed'),
   'observed='..tostring(v and v.status))
 end
end
do
 local m,r,s,time=fixture(); time(.010); m:step(0)
 check('deadline_starts_cleanup',s.worker.state=='terminating' or s.worker.state=='dead',s.worker.state)
 time(.011); s.worker.result={status='completed',values=codec.array({42})}; m:step(0)
 local v=m:preview(r)
 check('reached_deadline_frozen',not(v and v.status=='completed'), 'observed='..tostring(v and v.status))
end
do
 local m,r,s=fixture()
 local kill=m:accept('session_kill',{session_id=s.id})
 local v=m:preview(kill)
 check('kill_waits_for_cleanup',v==nil,'worker='..s.worker.state..' response='..tostring(v and v.error and v.error.code))
 check('request_id_cancellation_seam',type(m.cancel)=='function','cancel='..type(m.cancel))
end
assert(failures==0,tostring(failures)..' U6 acceptance gaps reproduced')
