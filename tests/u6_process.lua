local manager=require('lua_repl_mcp.manager')
local supervisor=require('lua_repl_mcp.worker_supervisor')
local codec=require('lua_repl_mcp.codec')
local x=require('lua_repl_mcp.worker_posix')
local null=require('lua_repl_mcp').null
local m=manager.new()
local function take(r)
 local until_time=x.now()+6
 repeat
  local v=m:commit(r,function(v)
   local f=assert(io.open(os.getenv('U6_RESPONSES'),'a')); f:write(assert(codec.encode({tool=r.tool,response=v})),'\n'); f:close(); return true
  end)
  if v then return v end
  m:step(2)
 until x.now()>until_time
 error('fixture watchdog: '..r.tool)
end
local function create() return take(m:accept('session_create',{})).session_id end
local function execute(id,code,timeout)
 return m:accept('session_execute',{session_id=id,code=code,wait_timeout_ms=null,execution_timeout_ms=timeout})
end
local function gone(pid) assert(x.w.wait(pid,x.w.WNOHANG)==nil,'worker not reaped') end
local ok,err=xpcall(function()
 local other=create()
 for _,code in ipairs({'while true do end','io.open('..string.format('%q',os.getenv('U6_DIR')..'/blocked.fifo')..',"r"):read(1)','require("posix.time").nanosleep({tv_sec=60,tv_nsec=0})'}) do
  local id=create(); local r=execute(id,code,40); local pid=r.session.worker.pid
  assert(take(execute(other,'return 17',null)).values[1]==17)
  local v=take(r); assert(v.error.code=='execution_timeout' and v.process_exit_confirmed)
  gone(pid); assert(not m.sessions[id])
 end
 print('PASS real_infinite_and_native_sleep_deadline_reap_independent_session')
 for _,kind in ipairs({'exit','signal','channel'}) do
  local id=create(); local r=execute(id,kind=='exit' and 'os.exit(23)' or 'while true do end',null)
  local w=r.session.worker
  m:step(2)
  if kind=='signal' then x.s.kill(w.pid,x.s.SIGTERM)
  elseif kind=='channel' then x.u.close(w.read_fd); w.read_fd=nil; w.eof=true end
  local v=take(r); assert(v.error.code==(kind=='channel' and 'transport_error' or 'worker_exited'),v.error.code)
  assert(v.process_exit_confirmed); gone(w.pid)
 end
 print('PASS real_os_exit_signal_live_channel_closure')
 local kid=create(); local kr=execute(kid,'while true do end',null); local kp=kr.session.worker.pid
 local killed=take(m:accept('session_kill',{session_id=kid}))
 assert(killed.status=='killed' and killed.process_exit_confirmed and not killed.error)
 gone(kp); assert(take(kr).error.code=='session_killed')
 local id=create(); local r=execute(id,'while true do end',null); m:bind('cancel',r)
 assert(m:cancel('cancel')); local w=r.session.worker
 local endtime=x.now()+5
 repeat m:step(2) until w.state=='dead' or x.now()>endtime
 assert(w.reaped and not m:preview(r)); gone(w.pid)
 local idle=create(); local running=execute(idle,'while true do end',null)
 local starting=m:accept('session_execute',{code='error("must not dispatch")',wait_timeout_ms=null})
 -- A rejected output enqueue (including a short-write adapter failure) must
 -- consume nothing, then connection disposal still owns every worker.
 local pending=m:accept('session_wait',{session_id=idle,wait_timeout_ms=0})
 assert(not m:commit(pending,function() return false end) and not pending.done)
 local pids={running.session.worker.pid,starting.session.worker.pid,m.sessions[other].worker.pid}
 assert(m:disconnect()); assert(not starting.execution)
 for _,pid in ipairs(pids) do gone(pid) end
 assert(#m.backend.workers==0 and #m.order==0 and next(m.sessions)==nil)
 print('PASS real_cancel_disconnect_starting_running_idle_inventory')
end,debug.traceback)
m:disconnect(); assert(ok,err)
-- Inject only OS wait/signal outcome and monotonic time: exercise the real
-- supervisor's 30s fallback rather than a mock manager terminal transition.
do
 local now=0; local b=supervisor.new{clock=function() return now end}
 local wait,kill=x.w.wait,x.s.kill
 local w={pid=999999,state='running',pending='',buffer='',execution_generation=1}
 b.workers={w}
 x.w.wait=function() return 0 end; x.s.kill=function() return 0 end
 b:abort(w,'execution_timeout'); now=29.999; b:step(0); assert(w.state=='terminating')
 now=30; b:step(0)
 assert(w.state=='dead' and w.process_exit_confirmed==false and w.failure=='execution_timeout')
 assert(#b.workers==0 and #b.reaping==1 and type(b.reaping[1])=='number')
 x.w.wait=function(pid) return pid,'exited',0 end; b:step(0); assert(#b.reaping==0)
 x.w.wait=wait; x.s.kill=kill
 print('PASS real_supervisor_injected_unreapable_30s_minimal_bookkeeping')
end
