-- Real TERM-resistant child: barrier establishes handler before abort.
local S=require('lua_repl_mcp.worker_supervisor')
local x=require('lua_repl_mcp.worker_posix')
local r,w=assert(x.u.pipe())
local pid=assert(x.u.fork())
if pid==0 then
 x.u.close(r); x.s.signal(x.s.SIGTERM,x.s.SIG_IGN)
 x.u.write(w,'ready'); x.u.close(w)
 while true do x.u.sleep(1) end
end
x.u.close(w); assert(x.u.read(r,5)=='ready'); x.u.close(r)
local b=S.new{}
local child={state='running',pid=pid,pending='',buffer=''}; b.workers={child}
local start=x.now(); local turns=0
local ok,err=pcall(function()
 b:abort(child,'session_killed')
 assert(child.state=='terminating')
 while child.state~='dead' and x.now()-start<24 do b:step(10); turns=turns+1 end
 assert(child.state=='dead' and child.reaped and child.process_exit_confirmed)
 assert(child.exit_reason=='killed' and child.exit_status==x.s.SIGKILL)
 local elapsed=x.now()-start
 assert(elapsed>=20 and elapsed<24 and turns>100)
 assert(not x.w.wait(pid,x.w.WNOHANG),'child already reaped')
 print('MEASURE TERM_resistant_elapsed='..elapsed..' responsive_turns='..turns)
end)
if not ok then x.s.kill(pid,x.s.SIGKILL); x.w.wait(pid); error(err) end
print('PASS real_TERM_resistant_child_KILL_transition_confirmed_reap')
