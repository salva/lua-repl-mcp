-- Real owned guardian exits; no workers allocated. Check before fixture reap.
local G=require('lua_repl_mcp.guardian')
local x=require('lua_repl_mcp.worker_posix')
local b=G.new{}
local pid=b.guardian_pid
-- Actual liveness EOF makes guardian exit normally; step must finalize ownership
-- after observing channel EOF, rather than treating descriptor closure as reap.
x.u.close(b.live); b.live=nil
local stop=x.now()+5
local failed=false
repeat
 local ok,msg=pcall(b.step,b,5)
 if not ok then failed=true; print('OBS failure='..tostring(msg)) end
 assert(x.now()<stop,'guardian EOF observation watchdog')
until failed
local clean=b:shutdown()
local repeated=b:shutdown()
-- WNOHANG distinguishes a retained zombie (pid returned) from already-reaped
-- ECHILD. This wait is fixture cleanup only AFTER recording product behavior.
local observed,reason,status=x.w.wait(pid,x.w.WNOHANG)
print('OBS F03 shutdown='..tostring(clean)..' repeated='..tostring(repeated)..' post_product_wait='..tostring(observed)..' reason='..tostring(reason)..' errno='..tostring(status))
assert(observed==nil and status==x.e.ECHILD,'F03 owned guardian not reaped by product before fixture wait')

-- Already-reaped owned child is an idempotent finalization success, not a leak.
local other=G.new{}
x.u.close(other.live); other.live=nil
assert(x.w.wait(other.guardian_pid)==other.guardian_pid)
assert(other:shutdown() and other:shutdown())
print('PASS already_reaped_guardian_idempotent_shutdown')
