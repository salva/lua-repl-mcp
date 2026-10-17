local manager=require('lua_repl_mcp.manager')
local null=require('lua_repl_mcp').null
local codec=require('lua_repl_mcp.codec')
local now=0
local b={clock=function() return now end,cwd='/fixture',workers={},count=0}
function b:allocate(o)
 self.count=self.count+1
 local w={state='starting',created_paths={},files_complete=false}; self.workers[#self.workers+1]=w; return w
end
function b:execute(w,input)
 assert(w.state=='idle'); w.state='running'; w.calls=(w.calls or 0)+1; return w.calls
end
function b:step() end
function b:abort(w) w.state='terminating' end
function b:shutdown() return true end
local m=manager.new{supervisor=b}
local function accept(t,a) return m:accept(t,a or {}) end
local function take(r) return assert(m:commit(r,function() return true end)) end
local function call(t,a) return take(accept(t,a)) end
local function list() return call('session_list').sessions end
local function finish(s,failed)
 s.worker.state='idle'; s.worker.result=failed and {status='failed',error=require('lua_repl_mcp.errors').new('lua_runtime_error','oops','execution','started')} or {status='completed',values=codec.array({7})}; m:refresh()
end
local function exec(id,wait,code)
 return accept('session_execute',{session_id=id,code=code or '',wait_timeout_ms=wait})
end
local function wait(id,timeout) return accept('session_wait',{session_id=id,wait_timeout_ms=timeout}) end
for _,a in ipairs({{code=false},{code='',wait_timeout_ms=false},{code='',execution_timeout_ms=0},{code='',create_options={cwd=false}},{code='',create_options={cwd='bad\0path'}},{code='',session_id='bad',create_options={}}}) do
 assert(call('session_execute',a).error.code=='invalid_arguments')
end
assert(b.count==0)
assert(call('session_wait',{session_id=null}).error.code=='invalid_arguments')
assert(call('session_wait',{session_id='missing'}).error.code=='unknown_session')
local cr=accept('session_create'); local s=cr.session; local id=s.id
assert(not m:preview(cr)); assert(list()[1].session_status=='starting')
s.worker.state='idle'; assert(take(cr).session_id==id)
assert(list()[1].execution_status=='none')
assert(take(wait(id,0)).error.code=='no_execution')
print('PASS validation_allocation_starting_idle_unknown_none')
local r=exec(id,0); local e=s.execution
assert(e.dispatch_at==0 and r.deadline==0)
finish(s); assert(take(r).status=='running') -- zero never consumes
assert(list()[1].result_available)
now=1000000; assert(list()[1].result_available) -- no TTL
local w1,w2=wait(id,null),wait(id,null)
assert(m:preview(w1).values[1]==7)
assert(not m:commit(w1,function() return false end)); assert(e.payload)
assert(not m:commit(w1,function() error('enqueue failed') end)); assert(e.payload)
assert(take(w2).values[1]==7)
local v=take(w1); assert(v.error.code=='result_unavailable' and v.status=='completed')
assert(not list()[1].result_available)
assert(take(wait(id,0)).error.code=='result_unavailable')
assert(s.worker.calls==1)
print('PASS zero_pending_retention_budget_commit_single_consumer')
for _,failed in ipairs({false,true}) do
 local x=exec(id,null); local a=wait(id,null); local c=wait(id,null)
 assert(not m:preview(x)); finish(s,failed)
 local invalid=call('session_execute',{session_id=id,code=false})
 assert(invalid.error.code=='invalid_arguments' and s.execution.payload)
 assert(list()[1].execution_status==(failed and 'failed' or 'completed'))
 local winner=take(a); assert(winner.status==(failed and 'failed' or 'completed'))
 if failed then assert(winner.error.code=='lua_runtime_error') end
 for _,loser in ipairs({x,c}) do assert(take(loser).error.code=='result_unavailable') end
end
print('PASS successful_failed_waiters_execute_compete_and_rejected_preserves')
now=10
local x=exec(id,100); local generation=s.execution
local pending=take(exec(id,0)); assert(pending.error.code=='session_busy' and s.execution==generation)
assert(list()[1].session_status=='running')
now=10.04; local w=wait(id,100)
assert(math.abs(x.deadline-10.1)<1e-9 and math.abs(w.deadline-10.14)<1e-9)
now=10.11; assert(take(x).status=='running'); assert(not m:preview(w))
now=10.15; assert(take(w).status=='running'); assert(s.worker.state=='running')
finish(s); assert(take(wait(id,0)).values[1]==7)
local defaults=exec(id,nil); assert(defaults.deadline==now+600)
local wd=wait(id,nil); assert(wd.deadline==now+600)
finish(s); assert(take(defaults).status=='completed'); assert(take(wd).error.code=='result_unavailable')
print('PASS positive_wait_origins_defaults_busy_preserves')
local finite=exec(id,10)
now=now+0.02; finish(s)
assert(take(finite).status=='running' and s.execution.payload)
assert(take(wait(id,0)).values[1]==7)
print('PASS expired_wait_does_not_consume_late_completion')
local old=exec(id,null); local ow=wait(id,null); finish(s,true)
local previous=s.execution
local fresh=exec(id,null)
assert(previous.replaced and not previous.payload)
for _,r0 in ipairs({old,ow}) do local v0=take(r0); assert(v0.error.code=='result_unavailable' and v0.status=='failed') end
assert(not m:preview(fresh)); finish(s); assert(take(fresh).values[1]==7)
print('PASS replacement_old_generation_waiters_no_history')
local implicit=exec(null,5); local si=implicit.session
assert(si.id~=id and not m:preview(implicit)); now=100; si.worker.state='idle'
m:step(0) -- dispatch without transport response polling
assert(si.worker.state=='running' and implicit.deadline==100.005)
assert(not m:preview(implicit)); assert(implicit.deadline==100.005)
finish(si,true); local iv=take(implicit); assert(iv.session_id==si.id and iv.error.code=='lua_runtime_error')
local before=s.execution
b:abort(s.worker); assert(take(exec(id,0)).error.code=='session_terminating'); assert(s.execution==before)
assert(list()[1].session_status=='terminating')
s.worker.state='dead'; m:refresh(); assert(call('session_wait',{session_id=id}).error.code=='unknown_session')
local newer=accept('session_create'); assert(newer.session.id~=id)
print('PASS implicit_dispatch_origin_actual_error_id_terminating_removal')
local final=exec(si.id,null); finish(si)
assert(take(final).status=='completed' and not final.execution.payload)
assert(m:disconnect()); assert(final.done)
print('PASS commit_before_disconnect')
print('PASS U5 deterministic policy groups')
