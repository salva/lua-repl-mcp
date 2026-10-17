local manager=require('lua_repl_mcp.manager')
local null=require('lua_repl_mcp').null
local codec=require('lua_repl_mcp.codec')
local posix=require('lua_repl_mcp.worker_posix')
local m=manager.new()
local function take(r,timeout)
 local deadline=posix.now()+(timeout or 5)
 repeat
  local v=m:commit(r,function(response)
   if os.getenv('U5_RESPONSES') then
    local f=assert(io.open(os.getenv('U5_RESPONSES'),'a'))
    f:write(assert(codec.encode({tool=r.tool,response=response})), '\n'); f:close()
   end
   return true
  end)
  if v then return v end
  m:step(2)
 until posix.now()>deadline
 error('request deadline')
end
local function call(tool,args) return take(m:accept(tool,args or {})) end
local function exec(id,code,wait) return m:accept('session_execute',{session_id=id,code=code,wait_timeout_ms=wait}) end
local function wait(id,t) return m:accept('session_wait',{session_id=id,wait_timeout_ms=t}) end
local ok,err=xpcall(function()
 local a=m:accept('session_create',{})
 local b=m:accept('session_create',{})
 local id1,id2=take(a).session_id,take(b).session_id
 assert(id1~=id2)
 assert(take(wait(id1,0)).error.code=='no_execution')
 local slow=exec(id1,'local p=require("posix.time"); p.nanosleep({tv_sec=0,tv_nsec=500000000}); n=(n or 0)+1; return n',0)
 assert(take(slow).status=='running')
 local old=m.sessions[id1].execution
 assert(take(exec(id1,'error("must not run")',0)).error.code=='session_busy')
 assert(m.sessions[id1].execution==old)
 local fast=take(exec(id2,'n=(n or 0)+1; return n',null))
 assert(fast.values[1]==1 and m.sessions[id1].worker.state=='running')
 local snapshot=call('session_list')
 local states={}; for _,v in ipairs(snapshot.sessions) do states[v.session_id]=v end
 assert(states[id1].session_status=='running' and states[id2].session_status=='idle')
 assert(not states[id2].result_available)
 local w1,w2=wait(id1,null),wait(id1,null)
 assert(take(w1).values[1]==1); assert(take(w2).error.code=='result_unavailable')
 assert(take(exec(id1,'return n',null)).values[1]==1)
 print('PASS real_two_worker_responsiveness_busy_exactly_once_waiters_listing')
 local pending=take(exec(null,'n=23; error("retained failure")',0))
 assert(pending.status=='running' and pending.session_id~=id1)
 local iid=pending.session_id
 local deadline=posix.now()+5
 repeat m:step(2) until m.sessions[iid].worker.state=='idle' or posix.now()>deadline
 assert(m.sessions[iid].worker.state=='idle')
 local bad=call('session_execute',{session_id=iid,code=false})
 assert(bad.error.code=='invalid_arguments')
 local fw1,fw2=wait(iid,null),wait(iid,null)
 assert(m:preview(fw1).error.code=='lua_runtime_error')
 assert(not m:commit(fw1,function() return false end))
 assert(take(fw2).error.code=='lua_runtime_error')
 local unavailable=take(fw1); assert(unavailable.error.code=='result_unavailable' and unavailable.status=='failed')
 assert(take(exec(iid,'return n',null)).values[1]==23)
 print('PASS real_implicit_error_id_retained_error_rejected_execute_commit_race')
 local oldExecute=exec(id2,'return 90',null)
 local oldWait=wait(id2,null)
 repeat m:step(2) until m.sessions[id2].worker.state=='idle'
 local replacement=exec(id2,'return 91',null)
 assert(take(oldWait).error.code=='result_unavailable')
 assert(take(oldExecute).error.code=='result_unavailable')
 local result=take(replacement); assert(result.values[1]==91)
 assert(not replacement.execution.payload)
 print('PASS real_old_waiters_replacement_commit_before_disconnect')
 local invalid=call('session_execute',{code='',wait_timeout_ms=false})
 assert(invalid.error.code=='invalid_arguments')
 local creation=call('session_execute',{code='return 1',create_options={cwd='/no-such-u5-directory'}})
 assert(creation.error.code=='session_creation_error' and not creation.session_id)
 print('PASS real_creation_failure_does_not_claim_execution')
 local delayed=exec(null,'return 81',null)
 local untilTime=posix.now()+5
 repeat m:step(2) until (delayed.execution and delayed.execution.status=='completed') or posix.now()>untilTime
 assert(take(delayed).values[1]==81) -- never previewed while allocating
 local finite=exec(id2,'local p=require("posix.time"); p.nanosleep({tv_sec=0,tv_nsec=80000000}); return 82',1)
 assert(take(finite).status=='running')
 assert(take(wait(id2,0)).status=='running')
 assert(take(wait(id2,1)).status=='running')
 assert(take(wait(id2,null)).values[1]==82)
 local relative=call('session_create',{cwd='docs/..'})
 local rows=call('session_list').sessions
 for _,row in ipairs(rows) do if row.session_id==relative.session_id then assert(row.cwd==posix.u.getcwd()) end end
 assert(take(wait('not-owned',0)).session_usable==false)
 print('PASS real_wait_modes_deferred_implicit_effective_cwd_unknown_id')
end,debug.traceback)
local clean,why=m:disconnect(); assert(clean,why)
assert(#m.order==0 and next(m.sessions)==nil)
if not ok then error(err) end
print('PASS U5 real manager groups')
