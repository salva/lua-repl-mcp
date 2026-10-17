-- Guardian-owned native supervisor; manager retains only logical worker mirrors.
local x=require('lua_repl_mcp.worker_posix')
local wire=require('lua_repl_mcp.guardian_channel')
local native=require('lua_repl_mcp.worker_supervisor')
local socket=require('posix.sys.socket')
local M={}; local B={}; B.__index=B
local fields={'state','failure','files_complete','created_paths','cwd','result','result_at',
 'execution_generation','execution_deadline','termination_started','cleanup_deadline',
 'process_exit_confirmed','exit_reason','exit_status','startup_message','reaped'}
local function guardian(fd,live,options)
 local backend=native.new(options); local allocations={}; local lost=false
 local ch=wire.new(fd,backend.limits.response_bytes)
 local commands={}
 x.nonblock(live)
 x.s.signal(x.s.SIGINT,x.s.SIG_IGN); x.s.signal(x.s.SIGTERM,x.s.SIG_IGN)
 local function dispose()
  lost=true
  for _,w in pairs(allocations) do backend:abort(w,'shutdown') end
 end
 local ok,err=pcall(function()
  while true do
   local data,_,errno=x.u.read(live,1)
   if data=='' then dispose() elseif not data and not x.retryable(errno) then dispose() end
   if not lost and not wire.busy(ch) then
    local open=wire.receive(ch,function(fragment,done)
     for _,cmd in ipairs(fragment) do
      assert(#commands<1024,'guardian command bound'); commands[#commands+1]=cmd
     end
     if not done then return end
     local batch=commands; commands={}
     assert(type(batch)=='table' and #batch<=1024,'guardian command bound')
     for _,cmd in ipairs(batch) do
      if cmd.op=='shutdown' then dispose(); break end
      local id=cmd.id
      assert(math.type(id)=='integer' and id>0,'invalid allocation identity')
      if cmd.op=='allocate' then
       assert(not allocations[id],'reused allocation')
       local count=0; for _ in pairs(allocations) do count=count+1 end
       assert(count<require('lua_repl_mcp.limits').admission(options.admission).sessions,'guardian capacity')
       local w=backend:allocate(cmd.options); allocations[id]=w
      else
       local w=assert(allocations[id],'stale allocation')
       if cmd.op=='execute' then assert(backend:execute(w,cmd.input,cmd.deadline))
       elseif cmd.op=='abort' then
        -- Commands carry the manager's original monotonic origin. Never reset
        -- an already running disposal when the liveness channel is lost.
        if w.state~='terminating' and w.state~='dead' then
         backend:abort(w,cmd.reason)
         w.termination_started=math.min(w.termination_started,cmd.started)
         w.cleanup_deadline=w.termination_started+30
        end
       elseif cmd.op=='close' then backend:graceful_close(w)
       elseif cmd.op=='release' then assert(w.state=='dead'); allocations[id]=nil
       else error('unknown guardian command') end
      end
     end
     if not lost then
      backend:step(0)
      local report={}
      for id,w in pairs(allocations) do
       local v={id=id}; for _,key in ipairs(fields) do v[key]=w[key] end
       report[#report+1]=v
      end
      wire.enqueue(ch,report)
     end
    end)
    if open==false then dispose() end
   end
   backend:step(0)
   if lost then
    if #backend.workers==0 then break end
   else wire.flush(ch) end
   local poll=lost and {} or {[live]={events={IN=true}},[fd]={events={IN=not wire.busy(ch),OUT=wire.busy(ch)}}}
   x.p.poll(poll,5)
  end
 end)
 if not ok then
  x.u.write(2,'guardian failure: '..tostring(err)..'\n')
  pcall(function() backend:shutdown() end)
 end
 x.u.close(fd); x.u.close(live); x.u._exit(ok and 0 or 1)
end
function M.new(options)
 options=options or {}
 local b=native.new(options)
 setmetatable(b,B); b.commands={}; b.by_id={}; b.inflight=false
 local owned={}
 local function keep(fd) owned[#owned+1]=fd; return fd end
 local ok,err=pcall(function()
  local r,w=x.u.pipe(); assert(r,w); keep(r); keep(w)
  local a,g=socket.socketpair(socket.AF_UNIX,socket.SOCK_STREAM,0); assert(a,g); keep(a); keep(g)
  for _,fd in ipairs(owned) do x.clo(fd,true) end
  local pid=assert(x.u.fork())
  if pid==0 then
   x.u.close(w); x.u.close(a)
   -- Close *all* unrelated manager descriptors before any worker can exist.
   x.close_except(r,g)
   guardian(g,r,options); x.u._exit(1)
  end
  b.guardian_pid=pid; b.live=w; b.channel=wire.new(a,b.limits.response_bytes)
  x.u.close(r); x.u.close(g); owned={}
 end)
 if not ok then for _,fd in ipairs(owned) do x.u.close(fd) end; error(err,0) end
 return b
end
function B:queue(v)
 assert(not self.closed and #self.commands<1024,'guardian command queue bound')
 if v.id and self.by_id[v.id] then self.by_id[v.id].dirty=true end
 self.commands[#self.commands+1]=v
end
function B:allocate(options)
 self.generation=self.generation+1
 local w={allocation_generation=self.generation,state='starting',created_paths={},files_complete=false,
  pending='',buffer='',execution_generation=0,deadline=self.clock()+self.timeout}
 self.workers[#self.workers+1]=w; self.by_id[self.generation]=w
 self:queue{op='allocate',id=self.generation,options=options or {}}
 return w
end
function B:execute(w,input,deadline)
 local ok,err=native.methods.execute(self,w,input,deadline)
 if not ok then return nil,err end
 w.pending=''
 self:queue{op='execute',id=w.allocation_generation,input=input,deadline=deadline}
 return ok
end
function B:abort(w,reason)
 if w.state=='terminating' or w.state=='dead' then return end
 native.methods.abort(self,w,reason)
 self:queue{op='abort',id=w.allocation_generation,reason=reason,started=w.termination_started}
end
function B:termination_signal() end -- manager must never signal worker PIDs
function B:graceful_close(w)
 local ok,err=native.methods.graceful_close(self,w)
 if ok then w.pending=''; self:queue{op='close',id=w.allocation_generation} end
 return ok,err
end
function B:step(delay)
 if self.closed then return end
 local ok,err=pcall(function()
  wire.flush(self.channel)
  local open=wire.receive(self.channel,function(report,done)
   assert(self.inflight,'unsolicited guardian report'); if done then self.inflight=false end
   for _,v in ipairs(report) do
    local w=assert(self.by_id[v.id],'unknown guardian allocation')
    -- An accepted kill/deadline freezes the outcome before its command is sent.
    if not w.dirty and (w.state~='terminating' or v.state=='dead') then
     local failure=w.state=='terminating' and w.failure
     for _,key in ipairs(fields) do w[key]=v[key] end
     w.failure=failure or w.failure
    end
    if w.state=='dead' then
     self:queue{op='release',id=v.id}; self.by_id[v.id]=nil
    end
   end
  end)
  assert(open~=false,'guardian channel lost')
  local pid=x.w.wait(self.guardian_pid,x.w.WNOHANG)
  assert(pid==0,'guardian exited')
  local live={}; for _,w in ipairs(self.workers) do
   if w.state~='dead' then
    live[#live+1]=w
    if w.state=='running' and w.execution_deadline and self.clock()>=w.execution_deadline then self:abort(w,'execution_timeout') end
   end
  end; self.workers=live
  if not self.inflight and not wire.busy(self.channel) then
   for _,cmd in ipairs(self.commands) do if cmd.id and self.by_id[cmd.id] then self.by_id[cmd.id].dirty=false end end
   wire.enqueue(self.channel,self.commands); self.commands={}; self.inflight=true
   wire.flush(self.channel)
  end
  x.p.poll({[self.channel.fd]={events={IN=true,OUT=wire.busy(self.channel)}}},delay or 0)
 end)
 if not ok then
  self.closed=true
  x.u.close(self.live); self.live=nil; x.u.close(self.channel.fd)
  -- No PID fallback: after guardian loss child identity is not safely owned.
  for _,w in ipairs(self.workers) do
   w.failure=w.failure or 'transport_failed'; w.state='dead'; w.process_exit_confirmed=false
  end
  self.workers={}
  error('guardian lost (worker exit unconfirmed): '..tostring(err),0)
 end
end
function B:shutdown()
 if self.closed then return false end
 for _,w in ipairs(self.workers) do self:abort(w,'shutdown') end
 repeat self:step(5) until #self.workers==0
 -- EOF is authoritative even when the output channel is backpressured.
 x.u.close(self.live); self.live=nil
 local deadline=self.clock()+1
 repeat
  local pid=x.w.wait(self.guardian_pid,x.w.WNOHANG)
  if pid==self.guardian_pid then self.closed=true; x.u.close(self.channel.fd); return true end
  x.p.poll({},5)
 until self.clock()>=deadline
 self.closed=true; x.u.close(self.channel.fd)
 x.u.write(2,'guardian disposal exit unconfirmed\n'); return false
end
return M
