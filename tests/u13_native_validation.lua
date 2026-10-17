local S=require('lua_repl_mcp.worker_supervisor')
local p=require('lua_repl_mcp.worker_protocol')
local c=require('lua_repl_mcp.codec')
local x=require('lua_repl_mcp.worker_posix')
local now=0
local s=S.new{clock=function() return now end}
local text=assert(p.encode(p.record('result',1,{execution_generation=1,result={status='completed',values=c.array{string.rep('a',262144)}}}),s.limits))
local read,poll,wait=x.u.read,x.p.poll,x.w.wait
x.p.poll=function() end
local function worker()
 local w={state='running',allocation_generation=1,execution_generation=1,execution_deadline=10,read_fd=101,buffer='',pending='',created_paths={}}
 s.workers={w}; local pos=1
 x.u.read=function(_,n)
  if pos>#text then return nil,'again',x.e.EAGAIN end
  local v=text:sub(pos,pos+n-1); pos=pos+#v; return v
 end
 while pos<=#text do s:step(0) end
 assert(w.state=='running' and not w.result,'complete raw frame applied without validation control turns')
 return w
end
local ok,err=pcall(function()
 local w=worker(); local turns=0
 while not w.result do turns=turns+1; assert(turns<30); s:step(0) end
 assert(turns>1 and w.state=='idle')
 w=worker(); s:abort(w,'request_cancelled',0); s:step(0)
 assert(not w.result and not w.validation and w.failure=='request_cancelled' and w.cleanup_deadline==30)
 for _,time in ipairs{10,10.001} do
  now=0; w=worker(); now=time; s:step(0)
  assert(w.failure=='execution_timeout' and not w.result and not w.validation)
 end
 now=0; w=worker(); w.pid=12345
 x.w.wait=function() return 12345,'exited',0 end
 s:step(0)
 assert(w.reaped and w.process_exit_confirmed and w.validation and not w.result)
 local turns=0
 while w.validation do turns=turns+1; assert(turns<30); s:step(0) end
 assert(w.state=='dead' and w.result and w.result_at==0 and w.failure=='worker_exited')
 x.w.wait=wait
 print('PASS native_pending_validation_completion_abort_equal_after_deadline_and_reap')
end)
x.u.read=read; x.p.poll=poll; x.w.wait=wait
assert(ok,err)
