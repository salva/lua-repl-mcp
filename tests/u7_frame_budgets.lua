-- Actual supervisor drain at the default private frame bound. Fake OS read
-- isolates length admission from JSON validity, without forging a smaller bound.
local supervisor=require('lua_repl_mcp.worker_supervisor')
local x=require('lua_repl_mcp.worker_posix')
local protocol=require('lua_repl_mcp.worker_protocol')
local limit=protocol.max_frame
local read,decode=x.u.read,protocol.decode
local ok,err=xpcall(function()
 for _,delta in ipairs({-1,0,1}) do
  local remaining=limit+delta
  local delimiter=false
  x.u.read=function(_,n)
   if remaining>0 then
    local count=math.min(n,remaining); remaining=remaining-count
    return string.rep('x',count)
   end
   if not delimiter then delimiter=true; return '\n' end
   return nil,'again',x.e.EAGAIN
  end
  local decoded=0
  protocol.decode=function(text) decoded=decoded+1; assert(#text==limit+delta); return {} end
  local s=supervisor.new{}
  local w={state='idle',read_fd=123,buffer=''}
  -- Avoid closing a nonexistent OS descriptor; record owning abort semantics.
  function s:abort(worker,cause) worker.failure=cause; worker.read_fd=nil end
  function s:receive() end
  local turns=0
  repeat
   s:drain(w); turns=turns+1
   assert(turns<10000,'frame admission/validation watchdog')
  until w.failure or (delimiter and not w.validation)
  if delta<=0 then assert(decoded==1 and not w.failure)
  else assert(decoded==0 and w.failure=='corrupt_worker') end
  assert(s.buffer_high_water<=limit)
  print('MEASURE worker_frame_delta='..delta..' retained_high_water='..s.buffer_high_water..' bound='..limit)
 end
end,debug.traceback)
x.u.read=read; protocol.decode=decode
assert(ok,err)
-- The production public codec separately accepts below/at input and refuses
-- above, independent of valid worker envelopes or manager result defaults.
local c=require('lua_repl_mcp.codec')
for _,delta in ipairs({-1,0,1}) do
 local text='"'..string.rep('i',16*1048576-2+delta)..'"'
 local v=c.decode(text)
 assert((v~=nil)==(delta<=0))
end
print('PASS default_worker_predecode_storage_and_public_input_boundaries')
