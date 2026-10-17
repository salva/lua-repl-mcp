-- Configured policy admits 64 individually bounded cwd inputs, but list
-- metadata can exceed the response budget before public fallback preflight.
local manager=require('lua_repl_mcp.manager')
local transport=require('lua_repl_mcp.client_transport')
local codec=require('lua_repl_mcp.codec')
local b={clock=function() return 0 end,cwd='/'}
function b:allocate(o) return {state='idle',cwd=o.cwd,created_paths={}} end
function b:step() end
function b:shutdown() return true end
local limits={input_bytes=131072,values_bytes=1024,diagnostic_bytes=256,max_depth=8,
 worker_bytes=1182208,response_bytes=4726272,output_bytes=4726273}
local m=manager.new{supervisor=b,limits=limits}
local cwd='/'..string.rep('d',99999)
for i=1,64 do
 local args={cwd=cwd}
 local input=assert(codec.encode({jsonrpc='2.0',id=i,method='tools/call',
  params={name='session_create',arguments=args}}))
 assert(#input<=limits.input_bytes)
 m:accept('session_create',args,i)
end
local t=transport.new(m,{read=function() return nil,'again' end,
 write=function() return nil,'again' end})
t:submit('list','session_list',{})
local payload=t.pending[1].request.response
local raw=assert(codec.encode(payload,{max_bytes=8*1048576,max_depth=40}))
assert(#raw>limits.response_bytes)
local ok,err=pcall(t.step,t,function() end)
print('MEASURE sessions=64 cwd_bytes='..#cwd..' list_payload='..#raw..
 ' response_bound='..limits.response_bytes..' step_returned_without_exception='..tostring(ok))
-- Correct behavior must preflight the complete response and send the existing
-- small limit_exceeded fallback without consuming any retained result.
assert(ok,'manager snapshot raises before bounded public fallback: '..tostring(err))
assert(not t.closed and t.bytes>0)
local wire=assert(codec.decode(t.queue[1].text))
assert(wire.result.structuredContent.error.code=='limit_exceeded')
