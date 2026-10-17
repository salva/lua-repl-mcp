-- Rare timing/ownership states without OS signalling or an unkillable process.
local x=require('lua_repl_mcp.worker_posix')
local S=require('lua_repl_mcp.worker_supervisor')
local now=19.5
local b=S.new{clock=function() return now end}
local kill,wait,poll,write=x.s.kill,x.w.wait,x.p.poll,x.u.write
local signals={}; local messages={}; local confirmed=false; local lost=false
x.s.kill=function(pid,sig) signals[#signals+1]={now,pid,sig}; return 0 end
x.w.wait=function(pid)
 if lost then return nil,'no child',x.e.ECHILD end
 if confirmed then return pid,'exited',0 end
 return 0
end
x.p.poll=function() return 0 end
x.u.write=function(fd,text) assert(fd==2); messages[#messages+1]=text; return #text end
local ok,err=pcall(function()
 local w={pid=123,state='running',pending='',buffer=''}; b.workers={w}
 b:abort(w,'execution_timeout',0)
 assert(w.cleanup_deadline==30 and signals[1][3]==x.s.SIGTERM)
 now=20; b:step(0); assert(signals[2][3]==x.s.SIGKILL)
 now=24; b:abort(w,'shutdown'); assert(w.cleanup_deadline==30)
 now=30; b:step(0)
 assert(w.state=='dead' and w.process_exit_confirmed==false and #b.workers==0)
 assert(#b.reaping==1 and type(b.reaping[1])=='number','retain only PID for eventual wait')
 assert(#messages==1 and messages[1]:find('unconfirmed',1,true))
 local n=#signals; confirmed=true; now=31; b:step(0)
 assert(#b.reaping==0 and #signals==n,'eventual reap must not signal')
 confirmed=false
 -- Handoff arriving after the original deadline must send no late signal.
 local v={pid=124,state='running',pending='',buffer=''}; b.workers={v}
 now=40; b:abort(v,'shutdown',0); assert(#signals==n)
 b:step(0); assert(v.state=='dead' and v.cleanup_deadline==30)
 -- Child ownership loss is not permission to retry a stale PID.
 local z={pid=125,state='idle',pending='',buffer=''}; b.workers={z}
 lost=true; b:step(0)
 assert(z.failure=='wait_failed' and z.pid==nil and #signals==n)
 print('PASS original_handoff_deadline_no_late_signal_unconfirmed_diagnostic_minimal_eventual_reap_stale_wait')
end)
x.s.kill=kill; x.w.wait=wait; x.p.poll=poll; x.u.write=write
assert(ok,err)
