-- Actual guardian once-generation transfer: retained and consumed results must
-- never be reintroduced by metadata refresh, replacement or disposal.
local G=require('lua_repl_mcp.guardian')
local M=require('lua_repl_mcp.manager')
local x=require('lua_repl_mcp.worker_posix')
local null=require('lua_repl_mcp').null
local b=G.new{}; local m=M.new{supervisor=b}
local function turn(predicate)
 local deadline=x.now()+10
 repeat m:step(0); assert(x.now()<deadline,'once-result watchdog') until predicate()
end
local function take(r)
 local result
 turn(function() result=m:commit(r,function() return true end); return result~=nil end)
 return result
end
local ok,err=pcall(function()
 local id=take(m:accept('session_create',{})).session_id
 for gen=1,3 do
  local r=m:accept('session_execute',{session_id=id,code='return '..gen,wait_timeout_ms=null})
  turn(function() return r.execution.status=='completed' end)
  assert(b.result_transfers==gen)
  for _=1,40 do m:step(1) end
  assert(b.result_transfers==gen,'retained result retransmitted')
  assert(take(r).values[1]==gen)
  for _=1,40 do m:step(1) end
  assert(b.result_transfers==gen,'consumed result retransmitted')
  assert(not r.execution.payload,'public consumption must release manager payload')
 end
 assert(take(m:accept('session_kill',{session_id=id})).status=='killed')
 assert(b.result_transfers==3,'disposal revived payload')
end)
local clean,why=pcall(function() assert(b:shutdown()) end)
assert(ok,err); assert(clean,why)
print('PASS three_generations_zero_retained_consumed_disposal_retransmissions')
