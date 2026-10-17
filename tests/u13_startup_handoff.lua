-- Late manager observation of startup must dispatch exactly once from step,
-- without preview/commit, preserving absolute execution/wait clocks.
local M=require('lua_repl_mcp.manager')
local null=require('lua_repl_mcp').null
for _,mode in ipairs{'step','cancel','dead'} do
 local now=0; local dispatches=0; local aborts=0
 local b={clock=function() return now end,cwd='/',owns_execution_deadlines=true}
 function b:allocate() self.worker={state='starting'}; return self.worker end
 function b:execute(w,input,deadline) dispatches=dispatches+1; w.state='running'; self.deadline=deadline; return dispatches end
 function b:abort(w,cause) aborts=aborts+1; w.state='dead'; w.failure=cause; w.process_exit_confirmed=true end
 function b:step() end
 local m=M.new{supervisor=b}
 local r=m:accept('session_execute',{code='return 73',execution_timeout_ms=1000,wait_timeout_ms=null},'startup')
 assert(r.starting and dispatches==0)
 now=20
 if mode=='cancel' then assert(m:cancel('startup'))
 elseif mode=='dead' then b.worker.state='dead'; b.worker.failure='startup_timeout'; b.worker.process_exit_confirmed=true
 else b.worker.state='idle' end
 m:step(0)
 if mode=='step' then
  assert(dispatches==1 and not r.starting and b.deadline==21)
  m:step(0); assert(dispatches==1)
  b.worker.result={status='completed',values={73}}; b.worker.result_at=20.5; b.worker.state='idle'
  now=22; m:step(0)
  assert(m:commit(r,function() return true end).values[1]==73)
 else
  assert(dispatches==0)
  if mode=='cancel' then assert(aborts==1 and r.cancelled)
  else assert(m:commit(r,function() return true end).error.reason=='startup_timeout') end
 end
 print('PASS original_startup_late_implicit_'..mode)
end
