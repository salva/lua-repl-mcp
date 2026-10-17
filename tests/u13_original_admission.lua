local c=require('lua_repl_mcp.codec')
local g=require('lua_repl_mcp.guardian').new{}
local m=require('lua_repl_mcp.manager').new{supervisor=g}
local t=require('lua_repl_mcp.client_transport').new(m,{read=function() return nil,'again' end,write=function(s) return #s end})
local ok,e=pcall(function()
 local data=c.array{}; for i=1,150000 do data[i]=1 end
 local body=assert(c.json_data(assert(c.encode({jsonrpc='2.0',id='original',method='tools/call',params={name='session_execute',arguments={wait_timeout_ms=0,code='return 73',args=c.array{data}}}}))))
 local execute=g.execute; g.execute=function() error('original revalidated after admission') end
 t:submit('original','session_execute',{code='error("non-authoritative")'},body)
 assert(t.preparation_count==1 and #m.order==0 and not m.requests.original)
 t:submit('list','session_list',{}); assert(m.requests.list)
 assert(t:cancel('original') and #m.order==0)
 t:submit('original','session_execute',{},body)
 local turns=0
 repeat assert(t:step(function() end)); turns=turns+1 until t.preparation_count==0
 assert(turns>2 and #m.order==1)
 local deadline=g.clock()+30
 while not (m.order[1].execution and m.order[1].execution.payload) do
  assert(g.clock()<deadline); assert(t:step(function() end))
 end
 assert(m.order[1].execution.payload.values[1]==73)
 assert(t:cancel('original')==false)
 local bad=assert(c.json_data('{"jsonrpc":"2.0","method":"tools/call","params":{"name":"session_list","arguments":{}}}'))
 t:submit('bad','session_execute',{code='return 1'},bad)
 assert(t.preparation_count==0 and #m.order==1)
 g.execute=execute
 t:close('test')
 print('PASS original_pre_admission_authority_cancel_reuse_late_dispatch_no_revalidation turns='..turns)
end)
g:shutdown(); assert(ok,e)
