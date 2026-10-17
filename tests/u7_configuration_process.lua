-- Configured limits survive exec, evaluator, manager and client encoder.
local manager=require('lua_repl_mcp.manager')
local transport=require('lua_repl_mcp.client_transport')
local x=require('lua_repl_mcp.worker_posix')
local c=require('lua_repl_mcp.codec')
local small={input_bytes=512,values_bytes=1024,diagnostic_bytes=256,max_depth=8,
 worker_bytes=69632,response_bytes=74240,output_bytes=74241}
local large={input_bytes=1024,values_bytes=2048,diagnostic_bytes=512,max_depth=16,
 worker_bytes=73728,response_bytes=82944,output_bytes=82945}
local function run(config)
 local m=manager.new{limits=config}
 local rd,wr=assert(x.u.pipe()); x.nonblock(rd); x.nonblock(wr)
 local t=transport.new(m,{read=function() return nil,'again' end,
  write=function(s) return x.u.write(wr,s) end})
 local function call(id,code)
  t:submit(id,'session_execute',{code=code,wait_timeout_ms=require('lua_repl_mcp').null})
  local text=''; local deadline=x.now()+8
  repeat
   assert(t:step(function() end)); assert(x.now()<deadline)
   while true do
    local s,_,e=x.u.read(rd,65536)
    if not s then assert(x.retryable(e)); break end
    assert(s~=''); text=text..s
   end
  until text:sub(-1)=='\n'
  local wire=assert(c.decode(text,{max_bytes=config.response_bytes,max_depth=config.max_depth+32}))
  assert(wire.id==id)
  assert(wire.result.content[1].text==assert(c.encode(wire.result.structuredContent,
   {max_bytes=config.response_bytes,max_depth=config.max_depth+32})))
  return wire.result.structuredContent
 end
 for _,delta in ipairs({-1,0,1}) do
  local r=call('size'..delta,'return string.rep("x",'..(config.values_bytes-4+delta)..')')
  if delta<=0 then assert(r.status=='completed' and #r.values[1]==config.values_bytes-4+delta)
  else assert(r.error.code=='result_serialization_error' and not r.values) end
 end
 for _,depth in ipairs({config.max_depth-1,config.max_depth,config.max_depth+1}) do
  local r=call('depth'..depth,'local v=0; for i=1,'..depth..' do v={v} end; return v')
  assert((r.status=='completed')==(depth<=config.max_depth))
 end
 local r=call('diagnostic','error(string.rep("d",1000))')
 assert(r.error.truncated and #r.error.message+#(r.error.traceback or '')<=config.diagnostic_bytes)
 assert(m.backend.limits.worker_bytes==config.worker_bytes)
 assert(t.response_bytes==config.response_bytes and t.input.limit==config.input_bytes)
 print('MEASURE configured_values='..config.values_bytes..' depth='..config.max_depth..
  ' worker_high_water='..m.backend.buffer_high_water..' worker_bound='..config.worker_bytes..
  ' output_high_water='..t.high_water..' output_bound='..config.output_bytes)
 t:close('done'); x.u.close(rd); x.u.close(wr)
 assert(next(m.sessions)==nil and next(m.backend.workers)==nil)
end
run(small); run(large)
print('PASS two_exec_worker_configurations_values_depth_diagnostic_transport_propagation')
