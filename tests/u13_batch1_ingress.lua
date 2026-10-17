-- Bounded real ingress gate: use external tests/containment.py ownership.
local c=require('lua_repl_mcp.codec')
local x=require('lua_repl_mcp.worker_posix')
local backend=(os.getenv('U13_GUARDIAN') and require('lua_repl_mcp.guardian') or require('lua_repl_mcp.worker_supervisor')).new()
local m=require('lua_repl_mcp.manager').new{supervisor=backend}
local function finish(r)
 local deadline=x.now()+60
 repeat
  m:step(5)
  local v=m:preview(r)
  if v then return v end
 until x.now()>=deadline
 error('bounded full ingress deadline')
end
local ok,why=pcall(function()
 local cr=m:accept('session_create',{})
 local created=finish(cr);assert(m:commit(cr,function() return true end))
 local args=c.array({});for i=1,1000000 do args[i]=0 end
 local r=m:accept('session_execute',{session_id=created.session_id,code='_G.ingress_witness=true',args=args,wait_timeout_ms=require('lua_repl_mcp').null})
 local v=finish(r)
 assert(v.error and v.error.code=='limit_exceeded' and v.error.stage=='execution' and v.error.execution_state=='not_started')
 assert(v.session_usable and m:commit(r,function() return true end))
 local next=m:accept('session_execute',{session_id=created.session_id,code='return _G.ingress_witness==nil,42',wait_timeout_ms=require('lua_repl_mcp').null})
 local success=finish(next);assert(success.values[1] and success.values[2]==42 and success.session_usable)
 print('PASS full million_argument_ingress_not_started_no_witness_session_recovery')
end)
backend:shutdown()
assert(ok,why)
