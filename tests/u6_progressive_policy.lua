-- Deterministic phase/retry/fallback and reap ordering; no real PID signalled.
local S=require('lua_repl_mcp.worker_supervisor')
local x=require('lua_repl_mcp.worker_posix')
local now=0
local b=S.new{clock=function() return now end}
local kill,wait,poll=x.s.kill,x.w.wait,x.p.poll
local sent={}; local exited=false; local polled
x.s.kill=function(pid,sig) sent[#sent+1]={now,sig}; return 0 end
x.w.wait=function(pid) if exited then return pid,'exited',0 end return 0 end
x.p.poll=function(_,delay) polled=delay; return 0 end
local ok,err=pcall(function()
 local w={state='running',pid=12345,pending='',buffer=''}; b.workers={w}
 b:abort(w,'execution_timeout'); assert(#sent==1 and sent[1][2]==x.s.SIGTERM)
 now=.999; b:step(5000); assert(#sent==1 and polled<=2)
 now=1; b:step(0); assert(#sent==2 and sent[2][2]==x.s.SIGTERM)
 now=7.5; b:step(0); assert(#sent==3,'no catch-up bursts')
 b:abort(w,'session_killed'); assert(w.failure=='execution_timeout' and w.cleanup_deadline==30)
 now=19.9; b:step(0); assert(sent[#sent][2]==x.s.SIGTERM)
 now=20; b:step(0); assert(#sent==5 and sent[5][2]==x.s.SIGKILL)
 now=20.9; b:step(0); assert(#sent==5)
 now=21; b:step(0); assert(#sent==6 and sent[6][2]==x.s.SIGKILL)
 now=30; b:step(0); assert(#sent==6 and w.state=='dead' and w.process_exit_confirmed==false)
 assert(#b.workers==0 and #b.reaping==1)
 -- Exit confirmation wins over a due retry, with no later signal.
 now=40; exited=false
 local v={state='idle',pid=12346,pending='',buffer=''}; b.workers={v}
 b:abort(v,'session_killed'); local count=#sent
 now=41; exited=true; b:step(0)
 assert(#sent==count and v.reaped and v.process_exit_confirmed and v.state=='dead')
 -- A single very late turn abandons without ever sending a late KILL.
 now=50; exited=false
 local late={state='idle',pid=12347,pending='',buffer=''}; b.workers={late}
 b:abort(late,'shutdown'); count=#sent
 now=81; b:step(0); assert(#sent==count and late.state=='dead')
end)
x.s.kill=kill; x.w.wait=wait; x.p.poll=poll
assert(ok,err)
print('PASS progressive_TERM20_KILL10_retry_no_burst_original_cause_reap_and_total_bound')
