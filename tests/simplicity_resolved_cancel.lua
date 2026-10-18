-- Simplicity continuation F01: resolved requests must not cancel other work.
-- Pure manager policy check; no native child/process-cleanup claim.
local manager=require('lua_repl_mcp.manager')
local codec=require('lua_repl_mcp.codec')
local failures=0
local function check(name,ok)
 print((ok and 'PASS ' or 'FAIL ')..name)
 if not ok then failures=failures+1 end
end
local function fixture()
 local b={clock=function() return 0 end,cwd='/fixture',aborts=0}
 function b:allocate() return {state='idle'} end
 function b:execute(w) w.state='running'; return 1 end
 function b:abort(w,cause) self.aborts=self.aborts+1; w.state='terminating'; w.failure=cause end
 function b:step() end
 local m=manager.new{supervisor=b}
 local function take(r) return assert(m:commit(r,function() return true end)) end
 local id=take(m:accept('session_create',{})).session_id
 local function execute(request_id)
  return m:accept('session_execute',{session_id=id,code='return 42',wait_timeout_ms=0},request_id)
 end
 local function finish(r)
  r.session.worker.result={status='completed',values=codec.array({42})}
  r.session.worker.state='idle'; m:refresh()
 end
 return m,b,id,execute,take,finish
end
do
 local m,b,id,execute,take=fixture()
 local active=execute('A')
 local rejected=execute('B')
 assert(m:preview(rejected).error.code=='session_busy')
 local cancelled=m:cancel('B')
 check('busy_rejection_cancel_preserves_active_generation',not cancelled and b.aborts==0 and active.session.worker.state=='running' and active.execution.status=='running')
 check('resolved_reply_commit_releases_slot_once',take(rejected).error.code=='session_busy' and m.slots.ordinary==1 and not m:cancel('B'))
end
do
 local m,b,id,execute=fixture()
 local wait=m:accept('session_wait',{session_id=id},'empty')
 assert(m:preview(wait).error.code=='no_execution')
 local active=execute('later')
 m:cancel('empty')
 check('resolved_no_execution_cancel_preserves_later_work',b.aborts==0 and active.execution.status=='running')
end
do
 local m,b=fixture()
 local created=m:accept('session_create',{},'create')
 assert(m:preview(created).session_status=='idle' and not created.starting)
 m:cancel('create')
 check('resolved_creation_cancel_preserves_idle_worker',b.aborts==0 and created.session.worker.state=='idle')
end
do
 local m,b,id,execute=fixture()
 local active=execute('active')
 assert(m:preview(active).status=='running')
 check('uncommitted_zero_wait_still_cancels_active',m:cancel('active') and b.aborts==1 and active.execution.status=='failed')
end
do
 local m,b,id,execute,take=fixture()
 local active=execute('answered'); take(active)
 check('committed_zero_wait_cancel_inert',not m:cancel('answered') and b.aborts==0 and active.session.worker.state=='running')
end
do
 local m,b,id,execute,take,finish=fixture()
 local active=execute('terminal'); finish(active)
 check('terminal_cancel_inert',not m:cancel('terminal') and b.aborts==0)
 -- The pending zero-wait reply does not consume the completed payload.
 take(active)
 local first=m:accept('session_wait',{session_id=id})
 assert(take(first).values[1]==42)
 local second=m:accept('session_wait',{session_id=id})
 check('terminal_result_consumed_once',take(second).error.code=='result_unavailable')
end
do
 local m,b,id,execute=fixture()
 execute('active')
 local kill=m:accept('session_kill',{session_id=id},'kill')
 assert(b.aborts==1 and not m:preview(kill))
 m:cancel('kill')
 check('accepted_kill_cancel_does_not_stop_cleanup',b.aborts==1 and kill.session.worker.state=='terminating' and not m:preview(kill))
end
assert(failures==0,tostring(failures)..' resolved-cancellation checks failed')
