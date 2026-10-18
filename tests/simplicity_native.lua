-- Real partial bulk, independent kill, rejection before restore, then reuse.
local x=require('lua_repl_mcp.worker_posix')
local G=require('lua_repl_mcp.guardian')
local M=require('lua_repl_mcp.manager')
local wire=require('lua_repl_mcp.guardian_channel')
local b=G.new{admission={sessions=2}}
local m=M.new{supervisor=b,admission={sessions=2}}
local read=x.u.read
local function take(r)
 local deadline=x.now()+15
 repeat local v=m:commit(r,function() return true end); if v then return v end
  m:step(0); assert(x.now()<deadline,'native acceptance watchdog') until false
end
local ok,err=pcall(function()
 local id=assert(take(m:accept('session_create',{})).session_id)
 local other=assert(take(m:accept('session_create',{})).session_id)
 local r=m:accept('session_execute',{session_id=id,code='return string.rep("x",16777212)'})
 local stop=x.now()+15
 repeat b:step(0); assert(x.now()<stop) until #b.commands==0 and not wire.busy(b.channel)
 -- Permit exactly a small prefix, then withhold further bulk only. Control and
 -- liveness are never intercepted. Actual nonzero bytes are the barrier.
 local bytes=0
 x.u.read=function(fd,n)
  if fd==b.channel.fd then
   if bytes>0 then return nil,'withheld',x.e.EAGAIN end
   local s,a,e=read(fd,math.min(n,128))
   if s then bytes=bytes+#s end
   return s,a,e
  end
  return read(fd,n)
 end
 repeat m:step(0); assert(x.now()<stop) until bytes>0
 local kill=take(m:accept('session_kill',{session_id=id}))
 assert(kill.process_exit_confirmed and not m.sessions[id])
 local generation=b.generation
 local rejected=take(m:accept('session_create',{}))
 assert(rejected.error.code=='limit_exceeded' and b.generation==generation)
 assert(m.sessions[other] and not b.closed)
 print('PASS native_partialbulk_kill_rejection_BEFORE_restore bytes='..bytes..' generation='..generation)
 x.u.read=read
 repeat m:step(0); assert(x.now()<stop) until b:can_allocate()
 local replacement=assert(take(m:accept('session_create',{})).session_id)
 assert(take(m:accept('session_execute',{session_id=other,code='return 73'})).values[1]==73)
 assert(take(m:accept('session_execute',{session_id=replacement,code='return 74'})).values[1]==74)
 print('PASS native_ordered_release_later_reuse_unrelated_session_preserved')
end)
x.u.read=read
local clean=b:shutdown()
local pid,_,errno=x.w.wait(b.guardian_pid,x.w.WNOHANG)
assert(ok,err); assert(clean and pid==nil and errno==x.e.ECHILD)
print('PASS native_owned_guardian_reaped_BEFORE_external_cleanup')
