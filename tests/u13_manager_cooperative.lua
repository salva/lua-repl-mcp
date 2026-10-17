-- Optional native adapter preparation yields before owning slots/IDs/state.
local c=require('lua_repl_mcp.codec')
local g=require('lua_repl_mcp.guardian').new{}
local m=require('lua_repl_mcp.manager').new{supervisor=g}
local function take(r)
 local stop=g.clock()+40
 repeat local v=m:commit(r,function() return true end); if v then return v end; m:step(0); assert(g.clock()<stop) until false
end
local ok,err=pcall(function()
 local id=take(m:accept('session_create',{})).session_id
 local active=m:accept('session_execute',{session_id=id,code='while true do end'},'active')
 local data=c.array{}; for i=1,150000 do data[i]=1 end
 local input={session_id=id,code='return 99',args=c.array{data}}
 local co=coroutine.create(function() return m:accept('session_execute',input,'pending',nil,coroutine.yield) end)
 local success=coroutine.resume(co); assert(success and coroutine.status(co)=='suspended')
 assert(not m.requests.pending and m.slots.ordinary==1)
 assert(#take(m:accept('session_list',{})).sessions==1)
 assert(m:cancel('active') and not m:cancel('active'))
 local turns=1; local r
 repeat
  local pass,value=coroutine.resume(co); assert(pass,value); r=value; turns=turns+1
  m:step(0)
 until coroutine.status(co)=='dead'
 assert(turns>2 and r.response.error and not r.execution,'resumed stale acceptance dispatched')
 assert(not active.execution.payload.values)
 take(m:accept('session_kill',{session_id=id}))
 -- Original request resolution and clone must also relinquish control.
 local id2=take(m:accept('session_create',{})).session_id
 local original=assert(c.json_data(assert(c.encode({jsonrpc='2.0',method='tools/call',params={name='session_execute',arguments={session_id=id2,code='return 73',args=c.array{data}}}}))))
 local w=m.sessions[id2].worker
 local before=w.execution_generation
 co=coroutine.create(function() return g:execute(w,nil,nil,original,coroutine.yield) end)
 assert(coroutine.resume(co)); assert(coroutine.status(co)=='suspended' and w.execution_generation==before)
 g:abort(w,'request_cancelled')
 repeat local pass,value=coroutine.resume(co); assert(pass,value) until coroutine.status(co)=='dead'
 assert(w.execution_generation==before and w.state~='running')
 print('PASS cooperative_manager_validation_list_cancel_no_stale_dispatch_original_abort turns='..turns)
end)
g:shutdown(); assert(ok,err)
