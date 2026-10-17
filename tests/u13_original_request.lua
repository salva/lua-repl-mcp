local c=require('lua_repl_mcp.codec')
local P=require('lua_repl_mcp.protocol')
local G=require('lua_repl_mcp.guardian')
local M=require('lua_repl_mcp.manager')
local x=require('lua_repl_mcp.worker_posix')
for _,numeric in ipairs{false,true} do
 local I=1500000; local V=1024; local E=128; local H=1048576
 local W=I+V+6*E+H; local R=I+3*W+H
 local limits={input_bytes=I,values_bytes=V,diagnostic_bytes=E,worker_bytes=W,response_bytes=R,output_bytes=R+1}
 local b=G.new{limits=limits}; local m=M.new{limits=limits,supervisor=b}
 local ok,err=pcall(function()
  local args=numeric and string.rep('1e-7,',50000)..'1e-7' or '"'..string.rep('\\u0001',200000)..'"'
  local text='{"jsonrpc":"2.0","id":"original-id","method":"tools/call","extra":{"preserve":"yes"},"params":{"name":"session_execute","arguments":{"code":"local a=...; return type(a)","args":['..args..'],"wait_timeout_ms":null}}}'
  assert(#text<I)
  local request
  local token=assert(c.json_data(text,{max_bytes=I,max_depth=132}))
  local framed=assert(c.encode({request=token},{max_bytes=#text+12,max_depth=133}))
  assert(framed=='{"request":'..text..'}','original must be JSON data, not quoted/re-encoded')
  assert(c.json_value(token).extra.preserve=='yes')
  c.json_value(token).extra.preserve='mutated'
  assert(c.json_value(token).extra.preserve=='yes','immutable original data')
  local core=P.new{input_bytes=I,names={session_execute=true},submit=function(id,tool,input,original)
   assert(c.json_bytes(original)==#text)
   request=m:accept(tool,input,id,original)
  end}
  core.state='ready'; core:handle(text); assert(request)
  local deadline=x.now()+20; local result
  repeat
   result=m:commit(request,function() return true end)
   if not result then m:step(0) end
   assert(x.now()<deadline,'original request watchdog')
  until result
  assert(result.status=='completed',assert(c.encode(result)))
  assert(result.values[1]==(numeric and 'number' or 'string'))
 end)
 local clean,why=pcall(function() assert(b:shutdown()) end)
 assert(ok,err); assert(clean,why)
 print('PASS complete_original_json_data_tight_floor_'..(numeric and 'short_numeric' or 'escaped'))
end
