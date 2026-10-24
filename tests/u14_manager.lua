-- Full original-ingress -> manager -> guardian -> executable -> same-state path.
local x=require('lua_repl_mcp.worker_posix')
local c=require('lua_repl_mcp.codec')
local null=require('lua_repl_mcp').null
local backend=require('lua_repl_mcp.guardian').new()
local manager=require('lua_repl_mcp.manager').new{supervisor=backend}
local script="package.path="..string.format('%q',package.path)..";package.cpath="..string.format('%q',package.cpath)..";native_like=function(n) return n+80 end;require('lua_repl_mcp.worker_main').main()"
local command=c.array{'lua5.4','-e',script}
local function take(r)
 local deadline=x.now()+10
 repeat
  local value=manager:commit(r,function() return true end)
  if value then return value end
  manager:step(5)
 until x.now()>deadline
 error('request deadline')
end
local function call(tool,args)
 local body=assert(c.json_data(assert(c.encode({jsonrpc='2.0',id=1,method='tools/call',params={name=tool,arguments=args}}))))
 return take(manager:accept(tool,{},nil,body))
end
local ok,err=xpcall(function()
 local created=call('session_create',{command=command})
 assert(created.session_id and not created.error)
 local result=call('session_execute',{session_id=created.session_id,code='host_value=native_like(2); return host_value',wait_timeout_ms=null})
 assert(result.values and result.values[1]==82)
 result=call('session_execute',{session_id=created.session_id,code='return host_value',wait_timeout_ms=null})
 assert(result.values[1]==82)
 local implicit=call('session_execute',{create_options={command=command},code='return native_like(3)',wait_timeout_ms=null})
 assert(implicit.session_id~=created.session_id and implicit.values[1]==83)
 for _,id in ipairs{created.session_id,implicit.session_id} do
  local killed=take(manager:accept('session_kill',{session_id=id}))
  assert(killed.status=='killed' and killed.process_exit_confirmed)
 end
end,debug.traceback)
assert(manager:disconnect()); assert(backend:shutdown()); assert(ok,err)
print('PASS immutable original explicit/implicit manager+guardian custom executable same-state and confirmed disposal')
