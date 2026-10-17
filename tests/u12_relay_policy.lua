-- Deterministic manager side of delegated guardian deadline arbitration.
local M=require('lua_repl_mcp.manager')
local null=require('lua_repl_mcp').null
for _,at in ipairs{.009,.010,.011} do
 for _,action in ipairs{'refresh','accept','step','kill'} do
  local now=0; local calls=0
  local b={clock=function() return now end,cwd='/',owns_execution_deadlines=true}
  function b:allocate() return {state='idle'} end
  function b:execute(w,_,deadline) w.state='running'; w.execution_deadline=deadline; return 1 end
  function b:abort(w,cause) calls=calls+1; w.state='terminating'; w.failure=cause end
  function b:step() end
  local m=M.new{supervisor=b}
  local id=m:commit(m:accept('session_create',{}),function() return true end).session_id
  local r=m:accept('session_execute',{session_id=id,code='',execution_timeout_ms=10,wait_timeout_ms=null})
  local w=r.session.worker
  now=1 -- mirror stale beyond deadline; all public refresh paths must agree
  if action=='refresh' then m:refresh()
  elseif action=='step' then m:step(0)
  elseif action=='accept' then m:accept('session_list',{})
  else m:accept('session_kill',{session_id=id}) end
  if action=='kill' then
   assert(calls==1 and r.execution.payload.error.code=='session_killed')
   w.state='dead'; w.result={status='completed',values={7}}; w.result_at=at
   m:refresh(); assert(r.execution.payload.error.code=='session_killed')
  else
   assert(calls==0 and r.execution.status=='running','stale mirror timed out')
   w.state='idle'; w.result={status='completed',values={7}}; w.result_at=at
   m:refresh()
   if at<.01 then
    assert(r.execution.status=='completed' and r.execution.completed_at==at and calls==0)
    m:terminate(r.session,'session_killed')
    assert(r.execution.status=='completed' and r.execution.payload.values[1]==7)
   else
    assert(calls==1 and r.execution.payload.error.code=='execution_timeout')
   end
  end
 end
end
print('PASS delegated_deadline_12_boundary_refresh_accept_step_kill_orderings')
