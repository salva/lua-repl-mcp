-- Separate session-population qualification: many small results, not maximal frames.
local G=require('lua_repl_mcp.guardian')
local M=require('lua_repl_mcp.manager')
local x=require('lua_repl_mcp.worker_posix')
local null=require('lua_repl_mcp').null
local admission={sessions=12}
local b=G.new{admission=admission}; local m=M.new{supervisor=b,admission=admission}
local function take(r)
 local stop=x.now()+20
 repeat local v=m:commit(r,function() return true end); if v then return v end; m:step(0); assert(x.now()<stop,'population watchdog') until false
end
local ok,err=pcall(function()
 local ids={}; local pending={}
 for i=1,12 do pending[i]=m:accept('session_create',{}) end
 for i,r in ipairs(pending) do ids[i]=assert(take(r).session_id) end
 pending={}
 for i,id in ipairs(ids) do pending[i]=m:accept('session_execute',{session_id=id,code='return '..i,wait_timeout_ms=null}) end
 local stop=x.now()+20
 repeat
  local complete=true
  for _,r in ipairs(pending) do if r.execution.status~='completed' then complete=false end end
  if complete then break end
  m:step(0); assert(x.now()<stop,'small completion watchdog')
 until false
 local transfers=b.result_transfers
 assert(transfers==12)
 for _=1,40 do m:step(1) end
 assert(b.result_transfers==transfers)
 for i,r in ipairs(pending) do assert(take(r).values[1]==i) end
 for _=1,40 do m:step(1) end
 assert(b.result_transfers==transfers)
 local list=take(m:accept('session_list',{})); assert(#list.sessions==12)
 local kills={}; for i,id in ipairs(ids) do kills[i]=m:accept('session_kill',{session_id=id}) end
 for _,r in ipairs(kills) do assert(take(r).process_exit_confirmed) end
 print('PASS admitted12_small_results_parallel_create_execute_dispose_zero_retransmission')
end)
b:shutdown(); assert(ok,err)
