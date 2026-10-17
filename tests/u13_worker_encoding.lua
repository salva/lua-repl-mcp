-- Isolate encoding from the already checkpointed validation passes.
local c=require('lua_repl_mcp.codec')
local p=require('lua_repl_mcp.worker_protocol')
local S=require('lua_repl_mcp.worker_supervisor')
local encode=c.encode
local encoding=false
c.encode=function(v,options)
 encoding=true
 local result,err=encode(v,options)
 encoding=false
 return result,err
end
local ok,err=pcall(function()
 for _,mode in ipairs{'success','abort','equal','after'} do
  local now=0; local s=S.new{clock=function() return now end}
  local w={state='idle',allocation_generation=1,execution_generation=0,created_paths={},pending=''}
  local slices=0
  local co=coroutine.create(function()
   return s:execute(w,{code='return 1',args=c.array{string.rep('\0',262144)}},10,nil,function()
    if encoding then slices=slices+1; coroutine.yield('encoding') else coroutine.yield('validation') end
   end)
  end)
  local found=false
  while coroutine.status(co)~='dead' do
   local success,value=coroutine.resume(co); assert(success,value)
   if value=='encoding' then
    found=true; assert(w.pending=='' and w.execution_generation==0 and w.state=='idle')
    if mode=='abort' then s:abort(w,'request_cancelled',0)
    elseif mode=='equal' then now=10 elseif mode=='after' then now=10.001 end
    break
   end
  end
  assert(found,'worker encoder completed without relinquishing control')
  while coroutine.status(co)~='dead' do local success,value=coroutine.resume(co); assert(success,value) end
  assert(slices>=4)
  if mode=='success' then assert(w.state=='running' and w.execution_generation==1 and #w.pending>262144)
  else assert(w.state=='terminating' and w.pending=='' and w.execution_generation==0) end
 end
 print('PASS worker_encoding_control_abort_equal_after_no_partial_dispatch')
end)
c.encode=encode; assert(ok,err)
