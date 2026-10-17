-- Reusable U4 supervisor. No public session/result-consumption policy lives here.
local x=require('lua_repl_mcp.worker_posix')
local p=require('lua_repl_mcp.worker_protocol')
local c=require('lua_repl_mcp.codec')
local M={}; local S={}; S.__index=S
function M.new(options)
 options=options or {}
 local limits=require('lua_repl_mcp.limits').connection(options.limits)
 local timeout=options.startup_timeout_ms; if timeout==nil then timeout=30000 end
 assert(type(timeout)=='number' and timeout==timeout and timeout>=1 and timeout<=2147483647 and timeout%1==0,'startup_timeout_ms must be an integer in [1,2147483647]')
 x.s.signal(x.s.SIGPIPE,x.s.SIG_IGN)
 return setmetatable({limits=limits,limit_options=require('lua_repl_mcp.limits').authored(limits),workers={},reaping={},generation=0,timeout=timeout/1000,clock=options.clock or x.now,
  buffer_high_water=0,pending_high_water=0,
  interpreter=options.interpreter or 'lua5.4',launch=options.launch},S)
end
local function close(w)
 for _,key in ipairs({'read_fd','write_fd'}) do if w[key] then x.u.close(w[key]); w[key]=nil end end
 w.pending=''; w.buffer=''; w.validation=nil; w.validation_rest=nil
end
-- One signal per eligible turn. Phase/deadline use the original monotonic
-- origin; a delayed turn never resets the total bound or replays missed ticks.
function S:termination_signal(w)
 if not w.pid or w.reaped then return end
 local now=self.clock()
 if now>=w.cleanup_deadline then return end
 local phase=now>=w.termination_started+20 and 'kill' or 'term'
 if phase~=w.termination_phase or now>=(w.next_signal_at or now) then
  x.s.kill(w.pid,phase=='kill' and x.s.SIGKILL or x.s.SIGTERM)
  w.termination_phase=phase; w.next_signal_at=now+1
 end
end
function S:abort(w,reason,started)
 if w.state=='terminating' or w.state=='dead' then return end
 w.failure=reason; w.state='terminating'; w.files_complete=false
 w.termination_started=math.min(self.clock(),started or self.clock()); w.cleanup_deadline=w.termination_started+30
 w.execution_deadline=nil
 close(w); self:termination_signal(w)
end
function S:allocate(options,started)
 -- Complete raw validation and detachment precedes descriptors/fork. Direct
 -- callers receive the same creation contract as manager-originated calls.
 local validated,problem=require('lua_repl_mcp.contracts').validate('session_create',options==nil and {} or options,
  {max_bytes=self.limits.input_bytes,max_depth=self.limits.max_depth})
 assert(validated,problem and problem.message)
 options=validated
 local now=self.clock()
 started=started or now
 assert(type(started)=='number' and started==started and started<=now and started>-math.huge,'invalid startup origin')
 self.generation=self.generation+1
 local w={allocation_generation=self.generation,state='starting',created_paths={},files_complete=false,
  deadline=started+self.timeout,buffer='',pending='',execution_generation=0}
 self.workers[#self.workers+1]=w
 if now>=w.deadline then
  w.state='dead'; w.failure='startup_timeout'; w.process_exit_confirmed=true
  return w -- no OS child or file side effect was created
 end
 local owned={}
 local function own(fd) if fd then owned[fd]=true end; return fd end
 local function release(fd) if owned[fd] then x.u.close(fd); owned[fd]=nil end end
 local ok,err=pcall(function()
 local r,write=x.u.pipe(); own(r); own(write)
 if not r then w.state='dead'; w.failure='spawn_failed'; return end
 local read,wr=x.u.pipe(); own(read); own(wr)
 if not read then w.state='dead'; w.failure='spawn_failed'; return end
 for _,fd in ipairs({r,write,read,wr}) do x.clo(fd,true) end
 local pid=x.u.fork()
 if pid==0 then
  local ok=pcall(function()
  x.s.signal(x.s.SIGINT,x.s.SIG_DFL); x.s.signal(x.s.SIGTERM,x.s.SIG_DFL)
  -- Avoid overlapping 0/1/2 even if caller started with closed standard FDs.
  local a=assert(x.f.fcntl(r,x.f.F_DUPFD,3)); local b=assert(x.f.fcntl(wr,x.f.F_DUPFD,3))
  x.close_except(a,b); x.clo(a,false); x.clo(b,false)
  local fd=x.f.open('/dev/null',x.f.O_RDWR)
  if not fd then x.u._exit(126) end
  for n=0,2 do assert(x.u.dup2(fd,n)) end
  if fd>2 then x.u.close(fd) end
  if self.launch then self.launch(a,b,w.allocation_generation,options); x.u._exit(0) end
  local script="package.path="..string.format('%q',package.path)..";package.cpath="..string.format('%q',package.cpath)..";require('lua_repl_mcp.worker_main').main("..a..","..b..","..w.allocation_generation..",assert(require('lua_repl_mcp.codec').decode("..string.format('%q',assert(c.encode(options)))..")),assert(require('lua_repl_mcp.codec').decode("..string.format('%q',assert(c.encode(self.limit_options or {})))..")))"
  x.u.execp(self.interpreter,{'-e',script})
  x.write_all(b,assert(p.encode(p.record('startup_error',w.allocation_generation,{reason='spawn_failed',message='worker exec failed'}),self.limits)))
  x.u._exit(127)
  end)
  x.u._exit(ok and 0 or 126)
 end
 if pid and pid>0 then w.pid=pid end -- ownership before any fallible parent setup
 release(r); release(wr)
 if not pid then w.state='dead'; w.failure='spawn_failed'; return end
 w.pid=pid; w.read_fd=read; w.write_fd=write
 x.nonblock(read); x.nonblock(write)
 owned[read]=nil; owned[write]=nil -- descriptor ownership transfers to worker
 end)
 for fd in pairs(owned) do pcall(x.u.close,fd) end
 if not ok then
  w.read_fd=nil; w.write_fd=nil
  w.startup_message=tostring(err)
  if w.pid then self:abort(w,'spawn_failed')
  else w.state='dead'; w.failure='spawn_failed' end
 end
 return w
end
function S:execute(w,input,deadline,original)
 if w.state~='idle' then return nil,'worker not idle' end
 if original then
  local resolved,problem=p.execution_input({request=original},self.limits)
  if not resolved then return nil,problem end
  input=resolved
 end
 -- Validate the direct evaluator arguments before dispatch.
 local args,e=require('lua_repl_mcp.contracts').validate('repl_execute',input,{max_depth=self.limits.max_depth,max_bytes=not original and self.limits.input_bytes or math.huge})
 if not args then return nil,e end
 local generation=w.execution_generation+1
 local record={execution_generation=generation}
 if original then record.request=original else record.input=args end
 local text,err=p.encode(p.record('execute',w.allocation_generation,record),self.limits)
 if not text then return nil,err end
 w.execution_generation=generation; w.result=nil; w.result_at=nil; w.execution_deadline=deadline; w.state='running'; w.pending=text; w.offset=1
 self.pending_high_water=math.max(self.pending_high_water,#text)
 return generation
end
function S:graceful_close(w)
 if w.state~='idle' then return nil,'worker not idle' end
 w.pending=assert(p.encode(p.record('close',w.allocation_generation),self.limits)); w.offset=1; w.state='closing'; return true
end
function S:receive(w,v)
 if w.state=='terminating' or w.state=='dead' then return end
 if v.allocation_generation~=w.allocation_generation then return self:abort(w,'handshake_failed') end
 if w.state=='starting' then
  if v.type=='file_created' then
   -- Only stdout/stderr creation notices are legal. Bound retained metadata
   -- even if a corrupt worker sends distinct paths indefinitely.
   if #w.created_paths>=2 then return self:abort(w,'handshake_failed') end
   if v.path:sub(1,1)~='/' then return self:abort(w,'handshake_failed') end
   for _,path in ipairs(w.created_paths) do if path==v.path then return self:abort(w,'handshake_failed') end end
   w.created_paths[#w.created_paths+1]=v.path
  elseif v.type=='ready' then w.cwd=v.cwd; w.state='idle'; w.files_complete=true
  elseif v.type=='startup_error' then w.startup_message=v.message; self:abort(w,v.reason)
  else self:abort(w,'handshake_failed') end
 elseif w.state=='running' and v.type=='result' and v.execution_generation==w.execution_generation then
  local now=self.clock() -- protocol.decode has fully validated the result
  if w.execution_deadline and now>=w.execution_deadline then return self:abort(w,'execution_timeout') end
  w.result=v.result; w.result_at=now; w.execution_deadline=nil; w.state='idle'
 else self:abort(w,'corrupt_worker') end
end
function S:drain(w)
 if w.validation then
  if self.turn_validated then return end
  self.turn_validated=true
  local ok,v=coroutine.resume(w.validation)
  if not ok then return self:abort(w,'corrupt_worker') end
  if coroutine.status(w.validation)~='dead' then return end
  w.validation=nil
  if not v then return self:abort(w,'corrupt_worker') end
  self:receive(w,v)
  if not w.read_fd then return end
 end
 local budget=math.min(self.limits.worker_bytes+1,self.turn_read_remaining or 65536)
 while w.read_fd and budget>0 do
  local text,_,err
  if w.validation_rest then text=w.validation_rest; w.validation_rest=nil
  else text,_,err=x.u.read(w.read_fd,math.min(65536,budget)) end
  if not text then if x.retryable(err) then return end; return self:abort(w,'transport_failed') end
  if text=='' then
   -- Endpoint closure is a logical worker loss, not proof of an OS exit.
   -- Keep it distinct from a locally failed/closed channel. wait alone owns
   -- exit confirmation/reason/status, which may become observable later.
   w.eof=true; w.control_eof=true; return
  end
  budget=budget-#text
  if self.turn_read_remaining then self.turn_read_remaining=self.turn_read_remaining-#text end
  -- Check length before adding an unbounded incomplete frame.
  local rest=text
  while w.read_fd do
   local nl=rest:find('\n',1,true)
   local part=nl and rest:sub(1,nl-1) or rest
   if #w.buffer+#part>self.limits.worker_bytes then return self:abort(w,'corrupt_worker') end
   w.buffer=w.buffer..part
   self.buffer_high_water=math.max(self.buffer_high_water,#w.buffer)
   if not nl then break end
   local frame=w.buffer; w.buffer=''
   w.validation=coroutine.create(function() return p.decode(frame,self.limits,coroutine.yield) end)
   rest=rest:sub(nl+1)
   if rest~='' then w.validation_rest=rest end
   return -- first validation slice belongs to the next native control turn
  end
 end
end
function S:step(timeout_ms)
 -- Share existing IO units across admitted workers. A frame's maximum size
 -- is a retention bound, not a per-worker loop quota. Rotate ownership so
 -- continuously readable peers cannot monopolize later turns.
 self.turn_read_remaining=65536; self.turn_write_remaining=65536; self.turn_validated=false
 local workers={}; local n=#self.workers
 local start=(self.turn_cursor or 0)%math.max(n,1)+1
 for i=0,n-1 do workers[#workers+1]=self.workers[(start+i-1)%n+1] end
 self.turn_cursor=start
 local poll={}; local now=self.clock(); local delay=timeout_ms or 0
 for _,w in ipairs(workers) do
  if w.state=='running' and w.execution_deadline then
   if now>=w.execution_deadline then self:abort(w,'execution_timeout')
   else delay=math.min(delay,math.max(0,math.ceil((w.execution_deadline-now)*1000))) end
  end
  if w.cleanup_deadline then
   local wake=w.cleanup_deadline
   if w.pid and not w.reaped then
    wake=math.min(wake,w.next_signal_at or now)
    if w.termination_phase~='kill' then wake=math.min(wake,w.termination_started+20) end
   end
   delay=math.min(delay,math.max(0,math.ceil((wake-now)*1000)))
  end
  if w.state=='starting' then
   if now>=w.deadline then self:abort(w,'startup_timeout') else delay=math.min(delay,math.max(0,math.ceil((w.deadline-now)*1000))) end
  end
  if w.read_fd then poll[w.read_fd]={events={IN=true}} end
  if w.write_fd and #w.pending>0 then poll[w.write_fd]={events={OUT=true}} end
 end
 x.p.poll(poll,delay)
 for _,w in ipairs(workers) do
  if w.state=='running' and w.execution_deadline and self.clock()>=w.execution_deadline then self:abort(w,'execution_timeout') end
  if w.state=='starting' and self.clock()>=w.deadline then self:abort(w,'startup_timeout') end
  if w.read_fd then self:drain(w) end
  if not w.control_eof and w.write_fd and #w.pending>0 and self.turn_write_remaining>0 then
   local n,_,err=x.u.write(w.write_fd,w.pending:sub(w.offset,w.offset+self.turn_write_remaining-1))
   if n and n>0 then self.turn_write_remaining=self.turn_write_remaining-n; w.offset=w.offset+n; if w.offset>#w.pending then w.pending=''; w.offset=1 end
   elseif not x.retryable(err) then self:abort(w,'transport_failed') end
  end
  if w.pid and not w.reaped then
   local pid,why,status=x.w.wait(w.pid,x.w.WNOHANG)
   if pid==w.pid then
    w.reaped=true; w.process_exit_confirmed=true; w.exit_reason=why; w.exit_status=status
    -- Drain already available data before recording exit; U6 owns full races.
    if w.read_fd then self:drain(w) end
    w.exit_pending=true

   elseif not pid then
    -- Ownership is no longer confirmable. Never signal a possibly reused PID.
    w.pid=nil; self:abort(w,'wait_failed')
   end
  end
  if w.exit_pending and not w.validation then
   if not w.failure and w.state~='closing' then w.failure=w.state=='starting' and 'handshake_failed' or 'worker_exited' end
   if w.state=='starting' then w.files_complete=false end
   close(w); w.state='dead'; w.exit_pending=nil
  end
  -- Reap before retrying: never signal again after confirmed child exit.
  if w.state=='terminating' then self:termination_signal(w) end
  if w.state=='terminating' and self.clock()>=w.cleanup_deadline then
   close(w); w.state='dead'; w.process_exit_confirmed=false
   if w.pid and not w.reaped then self.reaping[#self.reaping+1]=w.pid end
   x.u.write(2,'worker exit unconfirmed after bounded disposal; external side effects may continue\n')
  end
  if w.eof and not w.validation and w.state~='dead' and w.state~='closing' then self:abort(w,w.state=='starting' and 'handshake_failed' or (w.control_eof and 'worker_exited' or 'transport_failed')) end
 end
 local live={}; for _,w in ipairs(self.workers) do
  if w.state~='dead' then live[#live+1]=w end
 end; self.workers=live
 local pending={}; for _,pid in ipairs(self.reaping) do
  local got=x.w.wait(pid,x.w.WNOHANG)
  if got==0 then pending[#pending+1]=pid end
 end; self.reaping=pending
end
-- Shutdown is admission-independent; normal step performs bounded cleanup.
function S:shutdown()
 for _,w in ipairs(self.workers) do self:abort(w,'shutdown') end
 repeat self:step(5) until #self.workers==0
 return #self.reaping==0
end
M.methods=S
return M
