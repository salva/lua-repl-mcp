-- Independent audit of logical endpoint loss vs actual OS exit confirmation.
-- Only fake PID 999999 is observed by fakes; no native signal/wait receives it.
local x=require('lua_repl_mcp.worker_posix')
local S=require('lua_repl_mcp.worker_supervisor')
local wait,kill,poll,write=x.w.wait,x.s.kill,x.p.poll,x.u.write
local now=0; local signals={}; local messages={}
local ok,err=pcall(function()
 x.w.wait=function(pid) assert(pid==999999); return 0 end
 x.s.kill=function(pid,sig) assert(pid==999999); signals[#signals+1]=sig; return 0 end
 x.p.poll=function() return 0 end
 x.u.write=function(fd,text) assert(fd==2); messages[#messages+1]=text; return #text end
 for _,mode in ipairs{'endpoint','read_error','already_timed_out'} do
  now=0; signals={}; messages={}
  local b=S.new{clock=function() return now end}
  local r,wr=assert(x.u.pipe()); x.nonblock(r); x.u.close(wr)
  local w={pid=999999,state='running',allocation_generation=1,execution_generation=1,
   read_fd=r,pending='',buffer=''}
  b.workers={w}
  if mode=='read_error' then x.u.close(r) end -- EBADF is not endpoint EOF.
  if mode=='already_timed_out' then b:abort(w,'execution_timeout') end
  b:step(0)
  local cause=mode=='endpoint' and 'worker_exited' or
   (mode=='read_error' and 'transport_failed' or 'execution_timeout')
  assert(w.failure==cause and w.state=='terminating')
  assert(not w.process_exit_confirmed and not w.reaped and not w.exit_status)
  assert(#signals==1 and signals[1]==x.s.SIGTERM)
  now=20; b:step(0)
  assert(signals[2]==x.s.SIGKILL and not w.process_exit_confirmed)
  now=30; b:step(0)
  assert(w.state=='dead' and w.failure==cause and w.process_exit_confirmed==false)
  assert(not w.exit_reason and not w.exit_status and #b.reaping==1)
  assert(#messages==1 and messages[1]:find('unconfirmed',1,true))
  local n=#signals; now=31; b:step(0)
  assert(#signals==n,'eventual reap bookkeeping signalled abandoned PID')
  print('PASS audit_eof_'..mode..'_unconfirmed_original_cause_TERM_KILL_abandon')
 end
end)
x.w.wait,x.s.kill,x.p.poll,x.u.write=wait,kill,poll,write
assert(ok,err)
