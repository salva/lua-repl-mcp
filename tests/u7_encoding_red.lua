-- Remaining U7 red: a legal values array must survive compatibility wrapping.
-- No native dependencies; uses the actual owning protocol and worker encoders.
local codec=require('lua_repl_mcp.codec')
local protocol=require('lua_repl_mcp.protocol')
local worker=require('lua_repl_mcp.worker_protocol')
local limit=require('lua_repl_mcp.limits').evaluator().max_bytes
local failures=0
for _,delta in ipairs({-1,0,1}) do
 -- ASCII gives an exact array size: brackets + quotes + n bytes = n+4.
 local values=codec.array({string.rep('x',limit-4+delta)})
 local encoded=codec.encode(values,{max_bytes=limit})
 assert((encoded~=nil)==(delta<=0),'value boundary classification mismatch')
 if encoded then
  assert(#encoded==limit+delta)
  local payload={status='completed',values=values}
  local frame,err=worker.encode(worker.record('result',1,
    {execution_generation=1,result=payload}))
  assert(frame,'legal result rejected by worker encoder: '..tostring(err))
  local ok,result=pcall(protocol.tool_result,payload)
  if not ok then
   failures=failures+1
   print('FAIL legal_values_compatibility_wrap delta='..delta..
    ' values_bytes='..#encoded..' worker_bytes='..#frame..
    ' tool_result_raised='..type(result))
  else
   local text=assert(codec.decode(result.content[1].text,
    {max_bytes=worker.max_frame,max_depth=140}))
   assert(text.values[1]==values[1],'compatibility text differs from structuredContent')
   local response=assert(codec.encode({jsonrpc='2.0',id='boundary',result=result},
    {max_bytes=64*1048576,max_depth=160}))
   print('PASS legal_values_compatibility_wrap delta='..delta..
    ' values_bytes='..#encoded..' response_bytes='..#response)
  end
 else print('PASS values_above_bound_rejected delta='..delta) end
end
print('U7 remaining encoding gaps='..failures)
os.exit(failures==0 and 0 or 1)
