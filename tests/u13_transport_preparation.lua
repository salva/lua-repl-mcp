local c=require('lua_repl_mcp.codec')
local g=require('lua_repl_mcp.guardian').new{}
local m=require('lua_repl_mcp.manager').new{supervisor=g}
local t=require('lua_repl_mcp.client_transport').new(m,{read=function() return nil,'again' end,write=function(s) return #s end})
local ok,err=pcall(function()
 local data=c.array{}; for i=1,150000 do data[i]=1 end
 t:submit('pending','session_execute',{code='error("must not execute")',args=c.array{data}})
 assert(t:outstanding('pending') and t.preparation_count==1 and #m.order==0)
 t:submit('pending','session_execute',{code='return 1'})
 assert(t.preparation_count==1 and #t.queue==1)
 t:submit('list','session_list',{})
 assert(m.requests.list and m:preview(m.requests.list).sessions[1]==nil)
 assert(t:cancel('pending') and not t:cancel('pending'))
 assert(not t:outstanding('pending') and t.preparation_count==0)
 for _=1,12 do assert(t:step(function() end)) end
 assert(#m.order==0)
 t:submit('pending','session_execute',{code='return 73',args=c.array{data}})
 local n=0
 repeat assert(t:step(function() end)); n=n+1 until t.preparation_count==0
 assert(n>1 and #m.order==1)
 local capacity=m.admission.ordinary; m.admission.ordinary=m.slots.ordinary
 t:submit('overflow','session_execute',{code='return 1',args=c.array{data}})
 assert(t.preparation_count==0 and not t:outstanding('overflow'))
 m.admission.ordinary=capacity
 t:submit('other','session_execute',{code='return 1',args=c.array{data}})
 assert(t.preparation_count==1)
 t:close('test'); assert(t.preparation_count==0 and not next(t.preparing))
 print('PASS transport_preparation_id_list_cancel_reuse_handoff_disconnect turns='..n)
end)
g:shutdown(); assert(ok,err)
