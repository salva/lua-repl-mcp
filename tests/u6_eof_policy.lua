-- Complementary EOF/cleanup boundaries; original red fixture remains unchanged.
local S=require('lua_repl_mcp.worker_supervisor')
local x=require('lua_repl_mcp.worker_posix')
local wait,kill,poll=x.w.wait,x.s.kill,x.p.poll
local ok,err=pcall(function()
 for _,mode in ipairs{'eof_live','local_close','startup','deadline','kill','pending_write'} do
  local now=0; local observed=false; local signals=0
  local b=S.new{clock=function() return now end}
  local r,wr=x.u.pipe(); x.nonblock(r); x.u.close(wr)
  local w={pid=999999,state=mode=='startup' and 'starting' or 'running',deadline=10,
   read_fd=r,pending='',buffer='',execution_generation=1}
  if mode=='local_close' then x.u.close(r); w.read_fd=nil; w.eof=true end
  if mode=='pending_write' then w.write_fd=assert(x.u.dup(1)); w.pending='must not write after EOF'; w.offset=1 end
  if mode=='deadline' then w.execution_deadline=0 end
  x.w.wait=function(pid) assert(pid==w.pid); if observed then return pid,'exited',23 end; return 0 end
  x.s.kill=function(pid) assert(pid==w.pid); signals=signals+1; return 0 end
  x.p.poll=function() return 0 end
  b.workers={w}
  if mode=='kill' then b:abort(w,'session_killed') end
  b:step(0)
  local cause=mode=='startup' and 'handshake_failed' or mode=='local_close' and 'transport_failed'
   or mode=='deadline' and 'execution_timeout' or mode=='kill' and 'session_killed' or 'worker_exited'
  assert(w.failure==cause and w.state=='terminating' and not w.process_exit_confirmed)
  assert(w.exit_reason==nil and w.exit_status==nil and signals==1)
  local origin=w.termination_started
  now=20; b:step(0); assert(w.failure==cause and w.termination_started==origin and signals==2)
  if mode=='eof_live' then
   now=30; b:step(0)
   assert(w.state=='dead' and w.process_exit_confirmed==false and w.failure==cause)
   assert(w.exit_reason==nil and w.exit_status==nil and #b.reaping==1 and signals==2)
   observed=true; b:step(0); assert(#b.reaping==0 and signals==2)
  else
   observed=true; b:step(0)
   assert(w.state=='dead' and w.process_exit_confirmed and w.exit_status==23 and w.failure==cause and signals==2)
  end
  print('PASS native_eof_policy_'..mode)
 end
end)
x.w.wait=wait; x.s.kill=kill; x.p.poll=poll
assert(ok,err)
