-- U12 pinned-binding qualification. No production topology is selected implicitly.
local x=require('lua_repl_mcp.worker_posix')
local sock=require('posix.sys.socket')
assert(require('posix').version:match('36%.3$'))
assert(not sock.sendmsg and not sock.recvmsg, 'requalify descriptor passing')
local function pair()
 local a,b=assert(sock.socketpair(sock.AF_UNIX,sock.SOCK_STREAM,0))
 x.clo(a,true); x.clo(b,true); return a,b
end
local function read(fd)
 local s=assert(x.u.read(fd,1024)); assert(s~='','unexpected EOF'); return s
end
local function wait(pid)
 local got,why,status=x.w.wait(pid)
 assert(got==pid and why=='exited' and status==0,tostring(status))
end
if arg[1]=='signal' then
 local r,w=x.u.pipe(); x.nonblock(r); x.nonblock(w)
 local flag
 assert(x.s.signal(x.s.SIGTERM,function(sig) flag=sig end))
 local pid=assert(x.u.fork())
 if pid==0 then
  x.u.close(r); x.u.close(w)
  x.t.nanosleep{tv_sec=0,tv_nsec=100000000}
  x.s.kill(x.u.getppid(),x.s.SIGTERM); x.u._exit(0)
 end
 local start=x.now()
 local n,msg,errno=x.p.poll({[r]={events={IN=true}}},5000)
 local elapsed=x.now()-start
 assert(flag==x.s.SIGTERM,'Lua callback not dispatched at interrupted poll boundary')
 assert(elapsed<1,'shutdown did not wake idle poll')
 print('PASS signal_poll_boundary',n,msg,errno,string.format('%.3fs',elapsed))
 wait(pid); x.u.close(r); x.u.close(w)
 return
end
-- Separate manager liveness, commands, and response channels. A worker can
-- inherit neither liveness writer nor manager socket endpoints: guardian closes
-- them before it can fork a worker. Worker exec also performs the close sweep.
local live_r,live_w=x.u.pipe(); x.clo(live_r,true); x.clo(live_w,true)
local cmd_m,cmd_g=pair(); local out_m,out_g=pair()
local guardian=assert(x.u.fork())
if guardian==0 then
 x.u.close(live_w); x.u.close(cmd_m); x.u.close(out_m)
 x.s.signal(x.s.SIGPIPE,x.s.SIG_IGN)
 assert(read(cmd_g)=='spawn')
 local wr,ww=pair()
 local worker=assert(x.u.fork())
 if worker==0 then
  x.u.close(wr)
  -- Explicit close before exec, not only CLOEXEC.
  x.close_except(ww)
  x.clo(ww,false)
  local script="local u=require('posix.unistd'); local s=require('posix.signal'); local t=require('posix.time'); assert(s.signal(s.SIGTERM,s.SIG_IGN)); assert(u.write("..ww..",'ready:'..u.getpid()..':'..u.getppid())); while true do t.nanosleep{tv_sec=1,tv_nsec=0} end"
  x.u.execp('lua5.4',{'-e',script}); x.u._exit(127)
 end
 x.u.close(ww)
 local ready=read(wr)
 assert(x.write_all(out_g,ready))
 -- Acknowledged guardian/worker barrier precedes manager death, with worker
 -- TERM ignored before readiness, so this qualifies KILL escalation as well.
 assert(read(cmd_g)=='abort')
 local start=x.now(); local deadline=start+30; local phase,next_at
 local handed=false; local reaped=false; local terms,kills=0,0
 x.nonblock(live_r)
 while x.now()<deadline do
  local got=x.w.wait(worker,x.w.WNOHANG)
  if got==worker then reaped=true; break end
  assert(got==0,'lost guardian child identity')
  local now=x.now()
  local wanted=now>=start+20 and 'kill' or 'term'
  if phase~=wanted or now>=(next_at or now) then
   assert(x.s.kill(worker,wanted=='term' and x.s.SIGTERM or x.s.SIGKILL))
   phase=wanted; next_at=now+1
   if wanted=='term' then terms=terms+1 else kills=kills+1 end
   if terms==1 then assert(x.write_all(out_g,'term-started')) end
  end
  local s,_,err=x.u.read(live_r,1)
  if s=='' and not handed then
   handed=true
   assert(x.write_all(out_g,'handoff'))
  elseif not s then assert(x.retryable(err)) end
  x.p.poll({[live_r]={events={IN=true}}},10)
 end
 assert(handed and reaped,'handoff/reap not established')
 local elapsed=x.now()-start
 assert(elapsed>=20 and elapsed<23,'cleanup deadline reset on manager death')
 assert(terms>=18 and terms<=21 and kills==1,'progressive escalation mismatch')
 assert(x.write_all(out_g,string.format('disposed:%.3f:%d:%d',elapsed,terms,kills)))
 x.u._exit(0)
end
x.u.close(live_r); x.u.close(cmd_g); x.u.close(out_g)
assert(x.write_all(cmd_m,'spawn'))
local ready=read(out_m)
local worker,parent=ready:match('^ready:(%d+):(%d+)$')
assert(tonumber(parent)==guardian,'worker not guardian-owned at readiness')
assert(x.write_all(cmd_m,'abort'))
assert(read(out_m)=='term-started')
-- Closing the manager-only endpoint models its death while worker and guardian
-- remain alive. Inheritance retaining this endpoint would prevent the barrier.
x.u.close(live_w)
assert(read(out_m)=='handoff','worker/exec retained liveness writer')
local result=read(out_m)
assert(result:match('^disposed:'),result)
wait(guardian)
x.u.close(cmd_m); x.u.close(out_m)
print('PASS guardian_owned_exec_relay_private_liveness_TERM20_KILL10_original_deadline',result)
