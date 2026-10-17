local c=require('lua_repl_mcp.codec');local p=require('lua_repl_mcp.protocol')
local null=require('lua_repl_mcp').null
local manager=require('lua_repl_mcp.manager')
local function emit(tool,v,case)
 print(assert(c.encode{tool=tool,case=case,payload=v}))
end
local b={cwd=string.rep('x',20000),clock=function() return 0 end}
function b:allocate() return {state='idle'} end
function b:execute(w) w.state='running';return 1 end
function b:abort(w,reason) w.state='dead';w.failure=reason;w.reaped=true end
local m=manager.new{supervisor=b}
local cr=m:accept('session_create',{});local created=assert(m:preview(cr))
local function overflow(tool,v)
 local text,full=p.encode_result(1,v,{max_bytes=1024,max_depth=160},tool)
 assert(text and not full)
 local wire=assert(c.decode(text));assert(wire.result.isError)
 local dup=assert(c.decode(wire.result.content[1].text))
 assert(c.encode(dup)==c.encode(wire.result.structuredContent))
 if tool=='session_execute' or tool=='session_wait' then
  for _,key in ipairs({'session_id','session_status','session_usable'}) do assert(dup[key]==v[key]) end
 end
 emit(tool,wire.result.structuredContent,'actual overflow')
end
-- Actual create metadata can exceed a tight legal encoder budget via long ID.
local saved=m.prefix;m.prefix=string.rep('s',2000)
local large=m:accept('session_create',{});overflow('session_create',assert(m:preview(large)))
local large_id=assert(m:preview(large)).session_id
m.prefix=saved
m:commit(cr,function() return true end)
for _,tool in ipairs({'session_create','session_execute','session_wait','session_kill','session_list'}) do
 emit(tool,assert(m:preview(m:accept(tool,{extra=true}))),'invalid arguments')
end
overflow('session_list',assert(m:preview(m:accept('session_list',{}))))
local er=m:accept('session_execute',{session_id=created.session_id,code='',wait_timeout_ms=null})
er.session.worker.result={status='completed',values=c.array({string.rep('a',20000)})};er.session.worker.state='idle';m:refresh()
overflow('session_execute',assert(m:preview(er)))
overflow('session_wait',assert(m:preview(m:accept('session_wait',{session_id=created.session_id}))))
local kr=m:accept('session_kill',{session_id=created.session_id});m:refresh()
-- Actual non-overflow kill error and success outputs (overflow itself depends on ID size).
emit('session_kill',assert(m:preview(kr)),'kill success')

emit('session_kill',assert(m:preview(m:accept('session_kill',{session_id='unknown'}))),'unknown')
local evaluator=require('lua_repl_mcp.evaluator')
overflow('repl_execute',evaluator.execute{code='return string.rep("a",20000)'})
for _,code in ipairs({'error("ordinary")','local =','return function() end'}) do
 emit('repl_execute',evaluator.execute{code=code},'actual error')
end
-- Protocol validation for both direct tools.
local core=p.new{names={repl_execute=true,repl_close=true},tools=c.array({})}
core:handle('{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}')
core:handle('{"jsonrpc":"2.0","method":"notifications/initialized"}')
for _,tool in ipairs({'repl_execute','repl_close'}) do
 local r=core:handle(assert(c.encode{jsonrpc='2.0',id=1,method='tools/call',params={name=tool,arguments=false}}))
 emit(tool,r.result.structuredContent,'invalid arguments')
end

-- Legal coupled connection budgets, actual transport overflow and ownership.
local H=1048576
local limits={input_bytes=64,values_bytes=64,diagnostic_bytes=64,
 worker_bytes=H+512,response_bytes=4*H+4096,output_bytes=4*H+4097}
local backend={cwd=string.rep('c',3*H),clock=function() return 0 end}
function backend:allocate() return {state='idle'} end
function backend:step() end
local small=manager.new{supervisor=backend,limits=limits}
small:commit(small:accept('session_create',{}),function() return true end)
local transport=require('lua_repl_mcp.client_transport').new(small,{
 read=function() return nil,'again' end,write=function() return nil,'again' end})
transport:submit(1,'session_list',{})
assert(transport:step(function() error('unexpected ingress') end))
local v=assert(c.decode(transport.queue[1].text,{max_bytes=limits.response_bytes}))
assert(v.result.isError and not small.requests[1])
emit('session_list',v.result.structuredContent,'legal coupled transport overflow')
