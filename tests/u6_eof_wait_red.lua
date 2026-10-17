-- Native EOF may become visible one turn before wait(WNOHANG) observes exit.
-- Deterministic OS observations; no fake PID reaches native wait or signal.
local S=require('lua_repl_mcp.worker_supervisor')
local x=require('lua_repl_mcp.worker_posix')
local protocol=require('lua_repl_mcp.worker_protocol')
local codec=require('lua_repl_mcp.codec')
local wait,kill,poll=x.w.wait,x.s.kill,x.p.poll
local failures=0
local ok,err=pcall(function()
 for _,record in ipairs{'empty','partial','complete'} do
  for _,order in ipairs{'same_turn','next_turn'} do
   local b=S.new{}
   local r,wr=assert(x.u.pipe()); x.nonblock(r)
   local w={pid=999999,state='running',allocation_generation=1,execution_generation=1,
    read_fd=r,pending='',buffer=''}
   local frame=assert(protocol.encode(protocol.record('result',1,{execution_generation=1,
    result={status='completed',values=codec.array{7}}})))
   if record~='empty' then x.u.write(wr,record=='partial' and frame:sub(1,-3) or frame) end
   x.u.close(wr) -- EOF is independently observable before wait confirmation.
   local observed=false
   x.w.wait=function(pid) assert(pid==w.pid); if observed then return pid,'exited',23 end; return 0 end
   x.s.kill=function(pid) assert(pid==w.pid); return 0 end
   x.p.poll=function() return 0 end
   b.workers={w}
   observed=order=='same_turn'
   b:step(0)
   if order=='next_turn' then observed=true; b:step(0) end
   local pass=w.state=='dead' and w.process_exit_confirmed and w.exit_status==23
    and w.failure=='worker_exited' and ((w.result~=nil)==(record=='complete'))
   print((pass and 'PASS ' or 'FAIL ')..'native_eof_wait_'..order..'_'..record..
    ' failure='..tostring(w.failure)..' confirmed='..tostring(w.process_exit_confirmed)..
    ' result='..tostring(w.result~=nil))
   if not pass then failures=failures+1 end
   if w.read_fd then x.u.close(w.read_fd) end
  end
 end
end)
x.w.wait=wait; x.s.kill=kill; x.p.poll=poll
assert(ok,err)
assert(failures==0,'native EOF-before-wait classification or complete-result ordering gap')
