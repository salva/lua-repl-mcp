package.path=os.getenv('U9_INSTALLED_LUA_PATH') or './?.lua;./?/init.lua'
package.cpath=''
package.searchers={package.searchers[1],package.searchers[2]}
local h=require('lua_repl_mcp.handler')
local c=require('lua_repl_mcp.codec')
local function json(v) return assert(c.encode(v)) end
local function req(id,method,params) return json({jsonrpc='2.0',id=id,method=method,params=params})..'\n' end
local init=req(1,'initialize',{protocolVersion='old',capabilities={},clientInfo={name='fixture',version='1'}})..req(nil,'notifications/initialized')
local function call(id,name,args) return req(id,'tools/call',{name=name,arguments=args or {}}) end
local close=call(3,'repl_close')
local function adapter(input,split,short)
  local a={input=input,pos=1,out='',cleanup=0,flushes=0}
  a.read=function(n)
    if a.pos>#a.input then return nil,'eof' end
    n=math.min(n,split or n)
    local s=a.input:sub(a.pos,a.pos+n-1); a.pos=a.pos+#s; return s
  end
  a.write=function(s) local n=math.min(#s,short or #s); a.out=a.out..s:sub(1,n); return n end
  a.flush=function(...) assert(select('#',...)==0); a.flushes=a.flushes+1; return true end
  a.close=function() a.cleanup=a.cleanup+1 end; a.shutdown=a.close
  return a
end
local function responses(a)
 local r={}; for s in a.out:gmatch('([^\n]+)\n') do r[#r+1]=assert(c.decode(s)) end; return r
end
local count=0
local function test(name,f) f();count=count+1;print('PASS '..name) end

test('every_byte_boundary_and_short_writes',function()
 local stream=init..call(2,'repl_execute',{code='return 7,nil'})..close
 for split=1,#stream do
  local a=adapter(stream,split,3); local r=h.serve(a)
  assert(r.reason=='close_requested' and r.acknowledgement_sent and r.close_request_id==3 and a.cleanup==0)
  local out=responses(a); assert(out[1].result.protocolVersion=='2025-11-25')
  assert(out[2].result.structuredContent.values[1]==7 and out[2].result.structuredContent.values[2]==require('lua_repl_mcp').null)
  assert(out[3].result.structuredContent.status=='closing')
 end
end)
test('raw_handoff_and_parent_replay',function()
 local trailing='  { invalid raw } \n'..call(9,'repl_execute',{code='u2_late=(u2_late or 0)+1'})
 local partial=call(10,'repl_execute',{code='u2_late=(u2_late or 0)+10'})
 local a=adapter(init..close..trailing..partial:sub(1,17)); u2_late=nil
 local r=h.serve(a);assert(u2_late==nil and #r.pending_messages==2)
 assert(r.pending_messages[1]=='  { invalid raw } ' and r.pending_bytes==partial:sub(1,17))
 -- Parent reconstructs bytes, then resumes a new attachment explicitly.
 local replay=table.concat(r.pending_messages,'\n')..'\n'..r.pending_bytes..partial:sub(18)
 local b=adapter(init..replay);assert(h.serve(b).reason=='eof');assert(u2_late==11)
 -- Adapter-owned unread bytes never appear in the handoff.
 local d=adapter(init..close..trailing,#init+#close)
 local x=h.serve(d);assert(#x.pending_messages==0 and x.pending_bytes=='')
 assert(d.input:sub(d.pos)==trailing)
end)
test('read_write_flush_failures_and_progress',function()
 for _,read in ipairs({function() return nil,'broken' end,function() return '' end,function(n) return string.rep('x',n+1) end,function() error('read') end}) do
  local a=adapter('');a.read=read;assert(h.serve(a).reason=='transport_error' and a.cleanup==0)
 end
 for _,write in ipairs({function() return nil,'broken' end,function() return 0 end,function() return -1 end,function(s) return #s+1 end,function() return 1.5 end,function() error('write') end}) do
  local a=adapter(init..close);a.write=write;local r=h.serve(a);assert(r.reason=='transport_error' and not r.acknowledgement_sent)
 end
 for _,mode in ipairs({'write','flush','throw'}) do
  local a=adapter(init..close)
  local write=a.write
  a.write=function(s) if a.flushes==1 and mode=='write' then return nil,'close write failed' end;return write(s) end
  a.flush=function() a.flushes=a.flushes+1;if a.flushes==2 then if mode=='throw' then error('flush') end;return nil,'flush failed' end;return true end
  local r=h.serve(a);assert(r.reason=='close_requested' and not r.acknowledgement_sent and r.close_request_id==3 and r.diagnostics)
 end
end)
test('all_lifecycle_reasons_and_partial_eof',function()
 local a=adapter('partial');local r=h.serve(a);assert(r.reason=='eof' and r.pending_bytes=='partial')
 assert(h.serve({}).reason=='handler_error')
 assert(h.serve(adapter('12345'),{input_bytes=4}).reason=='handler_error')
 assert(h.serve(adapter(''),{read_bytes=0}).reason=='handler_error')
end)
test('protocol_errors_notifications_and_direct_contracts',function()
 local a=adapter(req(0,'tools/list')..'{\n[]\n'..init..req(2,'bogus')..call(4,'missing')..call(5,'repl_execute',{code='u2_bad=true',session_id='x'})..req(6,'tools/list')..req(nil,'tools/call',{name='repl_close'})..req(7,'ping')..close)
 local r=h.serve(a);assert(r.acknowledgement_sent and not u2_bad)
 local out=responses(a);assert(out[1].error and out[2].error.code==-32700 and out[3].error.code==-32600)
 assert(out[5].error.code==-32601 and out[6].error.code==-32602)
 assert(out[7].result.isError and out[7].result.structuredContent.error.code=='invalid_arguments')
 local tools=out[8].result.tools;assert(#tools==2 and tools[1].inputSchema.type=='object' and tools[1].outputSchema.type=='object')
 assert(not tools[1].inputSchema.properties.session_id and not tools[1].inputSchema.properties.execution_timeout_ms)
 for _,v in ipairs(out) do if v.result and v.result.structuredContent then assert(json(c.decode(v.result.content[1].text))==json(v.result.structuredContent)) end end
end)
test('invoking_thread_host_continuation_and_parent_policy',function()
 local thread=coroutine.running(); local oldprint,oldwrite=print,io.write; local active=false
 host_api=function() assert(coroutine.running()==thread);assert(active);u2_host=u2_host+1 end
 u2_host=40
 local a=adapter(init..call(2,'repl_execute',{code='host_api(); return u2_host'})..close)
 local write=a.write; a.write=function(s) assert(not active);return write(s) end
 -- The host callback runs entirely before the queued close is acknowledged.
 host_api=function() active=true;assert(coroutine.running()==thread);assert(a.flushes==1);u2_host=u2_host+1;active=false end
 local r=h.serve(a);assert(r.acknowledgement_sent and u2_host==41 and a.cleanup==0)
 assert(print==oldprint and io.write==oldwrite)
 u2_host=u2_host+1;assert(u2_host==42) -- host continues
 u2_host=nil;host_api=nil;a.close();assert(a.cleanup==1) -- parent-selected reset/cleanup
end)
test('invalid_key_wire_regression_and_error_recovery',function()
 local a=adapter(init..call(2,'repl_execute',{code='u2_once=(u2_once or 0)+1; return {["a/~"]={["\\255"]=1}}'})..call(4,'repl_execute',{code='return u2_once'})..close)
 assert(h.serve(a).acknowledgement_sent)
 local out=responses(a);local e=out[2].result.structuredContent.error
 assert(e.path=='/values/0/a~1~0' and out[2].result.isError and out[3].result.structuredContent.values[1]==1)
end)
test('response_budget_before_any_frame_write',function()
 local a=adapter(init..call(2,'repl_execute',{code='return string.rep("x",2000)'})..close)
 assert(h.serve(a,{response_bytes=1500}).acknowledgement_sent)
 local out=responses(a);assert(out[2].result.structuredContent.error.code=='limit_exceeded')
end)
test('close_short_write_failure_preserves_raw_tail',function()
 local a=adapter(init..close..'bad raw\ntail')
 local write=a.write;local written=0
 a.write=function(s)
   if a.flushes==1 then written=written+1;if written==2 then return nil,'broken after prefix' end;return write(s:sub(1,3)) end
   return write(s)
 end
 local r=h.serve(a);assert(r.reason=='close_requested' and not r.acknowledgement_sent)
 assert(r.pending_messages[1]=='bad raw' and r.pending_bytes=='tail')
end)
print('PASS '..count..' U2 groups')
