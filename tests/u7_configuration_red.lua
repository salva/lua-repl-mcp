-- Independent configured-limit coupling, not the normative-default conflict.
-- A configured public input budget permits an ID that even the small fallback
-- cannot echo under the configured response bound. Construction must reject it.
local manager=require('lua_repl_mcp.manager')
local transport=require('lua_repl_mcp.client_transport')
local protocol=require('lua_repl_mcp.protocol')
local c=require('lua_repl_mcp.codec')
local b={clock=function() return 0 end,cwd='/'}
function b:step() end
function b:shutdown() return true end
local m=manager.new{supervisor=b}
local id=string.rep('i',2000)
local request=assert(c.encode({jsonrpc='2.0',id=id,method='tools/call',
 params={name='session_list',arguments=c.object({})}},{max_bytes=4096}))
assert(#request<4096)
local fallback,original=protocol.encode_result(id,{values=c.array({string.rep('x',2048)})},
 {max_bytes=1024,max_depth=160})
assert(not fallback and not original,'fixture requires an ID too large for even error response')
local ok,t=pcall(transport.new,m,{read=function() return nil,'again' end,
 write=function() return nil,'again' end},
 {input_bytes=4096,response_bytes=1024,output_bytes=2048})
print('MEASURE input_bound=4096 legal_request='..#request..
 ' legal_ID='..#id..' response_bound=1024 output_bound=2048 constructor_accepted='..tostring(ok))
assert(not ok,'independently incompatible configured input/response limits accepted')
