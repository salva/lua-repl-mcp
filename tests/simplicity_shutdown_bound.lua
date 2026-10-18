-- R1: an owned but stopped guardian must not hold mirror drain indefinitely.
-- Run only under independent containment; all assertions precede harness cleanup.
local G=require('lua_repl_mcp.guardian')
local x=require('lua_repl_mcp.worker_posix')
local b=G.new{}
local w=b:allocate{}
local stop=x.now()+10
repeat b:step(5); assert(x.now()<stop,'startup watchdog') until w.state=='idle'
assert(x.s.kill(b.guardian_pid,x.s.SIGSTOP)) -- only our freshly forked guardian
local started=x.now()
local clean=b:shutdown()
local elapsed=x.now()-started
print('OBS stopped_guardian_shutdown returned='..tostring(clean)..' seconds='..elapsed)
assert(not clean and elapsed>=30 and elapsed<33,'shutdown did not honor single31s budget')
assert(b.closed and b.live==nil and not b.guardian_reaped)
assert(w.state=='dead' and w.process_exit_confirmed==false,'unreported worker exit claimed')
local deadline=b.finalize_deadline
local again=x.now()
assert(not b:shutdown() and x.now()-again<.5 and b.finalize_deadline==deadline,'repeat renewed budget')
print('PASS bounded_return_and_worker_guardian_uncertainty_BEFORE_cleanup')
-- Recover only the same still-owned guardian, then let product wait reap it.
assert(x.s.kill(b.guardian_pid,x.s.SIGCONT))
stop=x.now()+5
repeat
 clean=b:shutdown()
 if not clean then x.p.poll({},5) end
 assert(x.now()<stop,'recovery watchdog')
until clean
assert(b.finalize_deadline==deadline and b:shutdown())
local pid,_,errno=x.w.wait(b.guardian_pid,x.w.WNOHANG)
assert(pid==nil and errno==x.e.ECHILD,'fixture, not product, reaped guardian')
assert(w.process_exit_confirmed==false,'guardian reap changed worker certainty')
print('PASS recovery_idempotent_owned_reap_ECHILD_BEFORE_cleanup')
-- A transient interrupted wait must not be mistaken for ECHILD/reap or renew
-- an expired deadline; a later idempotent call can still observe owned reap.
local wait=x.w.wait
b.guardian_reaped=false
x.w.wait=function() return nil,'interrupted',x.e.EINTR end
assert(not b:shutdown() and not b.guardian_reaped and b.finalize_deadline==deadline)
x.w.wait=wait
assert(b:shutdown() and b.guardian_reaped and b.finalize_deadline==deadline)
print('PASS expired_deadline_EINTR_then_ECHILD_without_budget_reset')
