-- U6 policy permutations; injected backend never substitutes for process tests.
local manager=require('lua_repl_mcp.manager')
local null=require('lua_repl_mcp').null
local codec=require('lua_repl_mcp.codec')
local function fixture()
 local now=0
 local b={clock=function() return now end,cwd='/fixture'}
 function b:allocate() return {state='idle'} end
 function b:execute(w) w.state='running'; w.calls=(w.calls or 0)+1; return w.calls end
 function b:abort(w,cause) if w.state~='terminating' then w.state='terminating'; w.failure=cause end end
 function b:step() end
 local m=manager.new{supervisor=b}
 local cr=m:accept('session_create',{})
 local function take(r) return assert(m:commit(r,function() return true end)) end
 local id=take(cr).session_id
 local function exec(id2) return m:accept('session_execute',{session_id=id2 or id,code='',wait_timeout_ms=null,execution_timeout_ms=10}) end
 local function finish(s) s.worker.result={status='completed',values=codec.array({42})}; s.worker.result_at=now; s.worker.state='idle'; m:refresh() end
 local function dead(s,confirmed) s.worker.state='dead'; s.worker.process_exit_confirmed=confirmed; m:refresh() end
 return m,id,exec,take,function(t) now=t end,finish,dead,b
end
for _,confirmed in ipairs({true,false}) do
 for _,cause in ipairs({'session_killed','execution_timeout','transport_error','worker_exited','request_cancelled'}) do
  local m,id,exec,take,time,finish,dead=fixture()
  local r=exec(); m:bind('exec',r)
  local waiter=m:accept('session_wait',{session_id=id,wait_timeout_ms=null})
  local s=r.session; local kill
  if cause=='session_killed' then kill=m:accept('session_kill',{session_id=id})
  elseif cause=='execution_timeout' then time(.01); m:step(0)
  elseif cause=='request_cancelled' then assert(m:cancel('exec'))
  else s.worker.state='terminating'; s.worker.failure=cause; m:refresh() end
  assert(not m:preview(waiter)); if kill then assert(not m:preview(kill)) end
  s.worker.result={status='completed',values=codec.array({99})}; m:refresh()
  dead(s,confirmed)
  local v=take(waiter); assert(v.error.code==cause and v.process_exit_confirmed==confirmed)
  assert(confirmed or v.notice)
  if kill then local k=take(kill); assert(k.status=='killed' and not k.error and k.process_exit_confirmed==confirmed) end
  assert(not m.sessions[id] and #m.order==0)
 end
end
print('PASS five_fatal_causes_confirmed_and_fallback_original_cause_waiters')
for _,order in ipairs({'complete_kill_commit','complete_commit_kill','kill_complete_commit'}) do
 local m,id,exec,take,time,finish,dead=fixture()
 local r=exec(); local s=r.session; local k
 if order~='kill_complete_commit' then finish(s) end
 if order=='complete_commit_kill' then assert(take(r).values[1]==42) end
 k=m:accept('session_kill',{session_id=id})
 if order=='kill_complete_commit' then finish(s) end
 dead(s,true); assert(take(k).status=='killed')
 if order=='kill_complete_commit' then assert(take(r).error.code=='session_killed')
 elseif not r.done then assert(take(r).values[1]==42) end
end
print('PASS kill_completion_commit_order')
for _,stage in ipairs({'before_pending','after_pending','terminal','unknown'}) do
 local m,id,exec,take,time,finish,dead=fixture()
 local r=m:accept('session_execute',{session_id=id,code='',wait_timeout_ms=0},123)
 if stage=='after_pending' then take(r)
 elseif stage=='terminal' then finish(r.session) end
 local accepted=m:cancel(stage=='unknown' and '123' or 123)
 assert(accepted==(stage=='before_pending'))
 if accepted then assert(not m:preview(r)); dead(r.session,true) end
end
for _,tool in ipairs({'session_wait','session_kill','session_list','session_create'}) do
 local m,id,exec,take,time,finish,dead,b=fixture()
 local r=exec(); local s=r.session
 local input={session_id=id,wait_timeout_ms=null}
 -- list and creation have empty inputs; other tools cannot receive wait fields.
 if tool=='session_list' or tool=='session_create' then input={} end
 if tool=='session_kill' then input={session_id=id} end
 if tool=='session_create' then
  function b:allocate() return {state='starting'} end
 end
 local q=m:accept(tool,input,'q'); assert(m:cancel('q'))
 if tool=='session_list' then assert(s.worker.state=='running')
 else
  assert(q.session.worker.state=='terminating')
  if tool=='session_create' then
   q.session.worker.state='idle'; m:refresh(); assert(not q.execution and not q.session.worker.calls)
  end
 end
end
print('PASS request_id_type_binding_pending_commit_cancel_tools_late_ready')
do
 local m,id,exec,take,time,finish,dead=fixture()
 local r=exec(); finish(r.session); time(100); m:step(0)
 assert(r.session.worker.state=='idle' and take(r).values[1]==42)
 local next=exec(); assert(next.execution~=r.execution and next.execution.status=='running')
 assert(not m:cancel('missing'))
end
print('PASS completed_timer_disarmed_new_generation_inert_unknown_id')
