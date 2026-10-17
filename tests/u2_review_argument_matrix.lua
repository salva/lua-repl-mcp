-- Shared-protocol boundary matrix supplements the unchanged wire reproducer.
package.path=os.getenv('U9_INSTALLED_LUA_PATH') or './?.lua;./?/init.lua'
local codec=require('lua_repl_mcp.codec')
local protocol=require('lua_repl_mcp.protocol')
local null=require('lua_repl_mcp').null
local calls=0
local core=protocol.new({tools={},names={repl_close=true,repl_execute=true},call=function(name)
 calls=calls+1
 if name=='repl_close' then return {status='closing'},'close' end
 return {status='completed',values=codec.array({})}
end})
local function request(id,method,params)
 return core:handle(assert(codec.encode({jsonrpc='2.0',id=id,method=method,params=params})))
end
request(1,'initialize',{protocolVersion=protocol.version,capabilities={},clientInfo={name='matrix',version='1'}})
request(nil,'notifications/initialized')
for _,value in ipairs({false,true,null,0,'',codec.array({})}) do
 for _,name in ipairs({'repl_close','repl_execute'}) do
  local before=calls
  local response,action=request(2,'tools/call',{name=name,arguments=value})
  assert(response.result.isError and response.result.structuredContent.error.code=='invalid_arguments')
  assert(response.result.structuredContent.error.execution_state=='not_started')
  assert(action==nil and calls==before and core.state=='ready')
 end
end
for _,args in ipairs({{}, {arguments=codec.object({})}}) do
 args.name='repl_close'
 local response,action=request(3,'tools/call',args)
 assert(not response.result.isError and action=='close')
end
local before=calls
local response,action=request(4,'tools/call',{name='repl_execute'})
assert(response.result.isError and action==nil and calls==before)
response,action=request(5,'tools/call',{name='repl_execute',arguments={code=''}})
assert(not response.result.isError and action==nil and calls==before+1)
print('PASS explicit_argument_types_defaults_and_no_invalid_dispatch')
