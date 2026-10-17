-- Guardian-owned native supervisor; manager retains only logical worker mirrors.
local x=require('lua_repl_mcp.worker_posix')
local wire=require('lua_repl_mcp.guardian_channel')
local native=require('lua_repl_mcp.worker_supervisor')
local socket=require('posix.sys.socket')
local M={}; local B={}; B.__index=B
local fields={'state','failure','files_complete','created_paths','cwd','result','result_at',
 'execution_generation','execution_deadline','termination_started','cleanup_deadline',
 'process_exit_confirmed','exit_reason','exit_status','startup_message','reaped'}
local function guardian(fd,control,live,options)
 local backend=native.new(options); local allocations={}; local lost=false; local last_id=0
 local ch=wire.new(fd,backend.limits.response_bytes)
 local ctl=wire.new(control,4096)
 local controls={}
 local admission=require('lua_repl_mcp.limits').admission(options.admission)
 local pending_aborts={}
 local function abort(cmd)
  local w=allocations[cmd.id]
  if w then
   if w.state~='terminating' and w.state~='dead' then backend:abort(w,cmd.reason,cmd.started) end
  else
   -- Allocation can still be in bulk ingress. Keep its original origin and
   -- prevent this command being lost merely because the channels reorder.
   assert(cmd.id>last_id,'stale abort allocation')
   local count=0; for _ in pairs(pending_aborts) do count=count+1 end
   assert(pending_aborts[cmd.id] or count<admission.sessions,'guardian pending disposal bound')
   pending_aborts[cmd.id]=cmd
  end
 end
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
   if not lost then
    local open=wire.receive(ctl,function(items)
     for _,cmd in ipairs(items) do
      assert(math.type(cmd.id)=='integer' and cmd.id>0,'invalid guardian control')
      if cmd.op=='abort' then abort(cmd)
      elseif cmd.op=='ack' then
       local w=allocations[cmd.id]
       -- An ack may arrive after replacement or release on the bulk stream.
       -- It releases only the matching transferred generation, never new work.
       if w and cmd.generation==w.execution_generation and
        w.result_sent_generation==cmd.generation then w.result=nil end
      else error('unknown guardian control') end
     end
    end)
    if open==false then dispose() end
   end
   if not lost then
    local open=wire.receive(ch,function(fragment,done)
     -- A complete bounded frame is an independent command unit. Later
     -- commands in the sender batch are not a barrier to applying this one.
     for _,cmd in ipairs(fragment) do
      if cmd.op=='shutdown' then dispose(); break end
      local id=cmd.id
      assert(math.type(id)=='integer' and id>0,'invalid allocation identity')
      if cmd.op=='allocate' then
       assert(id>last_id and not allocations[id],'reused allocation'); last_id=id
       local count=0; for _ in pairs(allocations) do count=count+1 end
       assert(count<require('lua_repl_mcp.limits').admission(options.admission).sessions,'guardian capacity')
       local w=backend:allocate(cmd.options,cmd.started); allocations[id]=w
       if pending_aborts[id] then abort(pending_aborts[id]); pending_aborts[id]=nil end
      else
       local w=assert(allocations[id],'stale allocation')
       if cmd.op=='execute' then
        assert(cmd.generation==w.execution_generation+1,'stale execution generation')
        if w.state~='terminating' and w.state~='dead' then assert(backend:execute(w,cmd.input,cmd.deadline,cmd.request)) end
       elseif cmd.op=='abort' then
        -- Commands carry the manager's original monotonic origin. Never reset
        -- an already running disposal when the liveness channel is lost.
        if w.state~='terminating' and w.state~='dead' then
         backend:abort(w,cmd.reason,cmd.started)
        end
       elseif cmd.op=='close' then backend:graceful_close(w)
       elseif cmd.op=='release' then assert(w.state=='dead'); allocations[id]=nil
       else error('unknown guardian command') end
      end
     end
    end)
    if open==false then dispose() end
   end
   backend:step(0)
   if not lost and not wire.busy(ch) then
    local report={}
    for id,w in pairs(allocations) do
     -- Only changed bounded metadata is relayed, never periodic snapshots.
     local changed=not w.reported
     local prior=w.reported or {}
     for _,key in ipairs(fields) do
      if key~='result' and prior[key]~=w[key] then changed=true end
     end
     if prior.path_count~=#w.created_paths then changed=true end
     local transfer=w.result and w.result_sent_generation~=w.execution_generation
     if changed or transfer then
      local v={id=id}; local saved={path_count=#w.created_paths}
      for _,key in ipairs(fields) do
       if key~='result' then v[key]=w[key]; saved[key]=w[key] end
      end
      if transfer then
       v.result=w.result; v.result_transfer=true
       w.result_sent_generation=w.execution_generation
      end
      w.reported=saved; report[#report+1]=v
     end
    end
    if #report>0 then wire.enqueue(ch,report) end
   end
   if not lost then
    for id,w in pairs(allocations) do
     if w.control_state~=w.state then
      local v=controls[id] or {id=id}; controls[id]=v
      v.observed_state=w.state; v.failure=w.failure
      v.execution_generation=w.execution_generation
      w.control_state=w.state
     end
     if w.result_at and w.validated_sent~=w.execution_generation then
      local v=controls[id] or {id=id}; controls[id]=v
      v.validated_generation=w.execution_generation; v.result_at=w.result_at
      w.validated_sent=w.execution_generation
     end
    end
    -- Exit confirmation is small, once per allocation, and cannot depend on
    -- result/path/diagnostic bulk delivery. Never send input-sized fields here.
    for id,w in pairs(allocations) do
     if w.state=='dead' and not w.control_dead_sent then
      local v=controls[id] or {id=id}; controls[id]=v
      v.state='dead'; v.failure=w.failure; v.process_exit_confirmed=w.process_exit_confirmed
      v.exit_reason=w.exit_reason; v.exit_status=w.exit_status
      w.control_dead_sent=true
     end
    end
    if not wire.busy(ctl) and next(controls) then
     local batch={}; for _,v in pairs(controls) do batch[#batch+1]=v end
     assert(#batch<=admission.sessions,'guardian pending metadata bound')
     wire.enqueue(ctl,batch); controls={}
    end
    wire.flush(ctl)
   end
   if lost then
    if #backend.workers==0 then break end
   else wire.flush(ch) end
   local poll=lost and {} or {[live]={events={IN=true}},[control]={events={IN=true,OUT=wire.busy(ctl)}},[fd]={events={IN=true,OUT=wire.busy(ch)}}}
   x.p.poll(poll,5)
  end
 end)
 if not ok then
  x.u.write(2,'guardian failure: '..tostring(err)..'\n')
  pcall(function() backend:shutdown() end)
 end
 x.u.close(fd); x.u.close(control); x.u.close(live); x.u._exit(ok and 0 or 1)
end
function M.new(options)
 options=options or {}
 local b=native.new(options)
 -- Native receive/deadline arbitration occurs in the guardian, before relay.
 -- A manager mirror can remain running while a validated result is in flight.
 b.owns_execution_deadlines=true
 b.control_capacity=require('lua_repl_mcp.limits').admission(options.admission).sessions
 b.command_capacity=4*b.control_capacity
 setmetatable(b,B); b.commands={}; b.by_id={}; b.control_commands={}
 local owned={}
 local function keep(fd) owned[#owned+1]=fd; return fd end
 local ok,err=pcall(function()
  local r,w=x.u.pipe(); assert(r,w); keep(r); keep(w)
  local a,g=socket.socketpair(socket.AF_UNIX,socket.SOCK_STREAM,0); assert(a,g); keep(a); keep(g)
  local ca,cg=socket.socketpair(socket.AF_UNIX,socket.SOCK_STREAM,0); assert(ca,cg); keep(ca); keep(cg)
  for _,fd in ipairs(owned) do x.clo(fd,true) end
  -- Configure parent endpoint before fork: construction failure cannot leave
  -- an untracked guardian, and no child exists until all descriptors are ready.
  local channel=wire.new(a,b.limits.response_bytes)
  local control_channel=wire.new(ca,4096)
  x.nonblock(r)
  local pid=assert(x.u.fork())
  if pid==0 then
   x.u.close(w); x.u.close(a); x.u.close(ca)
   -- Close *all* unrelated manager descriptors before any worker can exist.
   local ok=pcall(function()
    x.close_except(r,g,cg)
    guardian(g,cg,r,options)
   end)
   x.u._exit(ok and 0 or 1)
  end
  b.guardian_pid=pid; b.live=w; b.channel=channel; b.control_channel=control_channel
  x.u.close(r); x.u.close(g); x.u.close(cg); owned={}
 end)
 if not ok then for _,fd in ipairs(owned) do x.u.close(fd) end; error(err,0) end
 return b
end
function B:queue(v)
 assert(not self.closed and #self.commands<self.command_capacity,'guardian command queue bound')
 if v.id and self.by_id[v.id] then self.by_id[v.id].dirty=true end
 self.commands[#self.commands+1]=v
end
function B:allocate(options)
 local validated,problem=require('lua_repl_mcp.contracts').validate('session_create',options==nil and {} or options,
  {max_bytes=self.limits.input_bytes,max_depth=self.limits.max_depth})
 assert(validated,problem and problem.message)
 local started=self.clock()
 self.generation=self.generation+1
 local w={allocation_generation=self.generation,state='starting',created_paths={},files_complete=false,
  pending='',buffer='',execution_generation=0,deadline=started+self.timeout}
 self.workers[#self.workers+1]=w; self.by_id[self.generation]=w
 self:queue{op='allocate',id=self.generation,options=validated,started=started}
 return w
end
function B:execute(w,input,deadline,original)
 local ok,err=native.methods.execute(self,w,input,deadline,original)
 if not ok then return nil,err end
 w.pending=''
 self:queue{op='execute',id=w.allocation_generation,input=not original and input or nil,request=original,deadline=deadline,generation=w.execution_generation}
 return ok
end
function B:abort(w,reason)
 if w.state=='terminating' or w.state=='dead' then return end
 native.methods.abort(self,w,reason)
 assert(#self.control_commands<2*self.control_capacity,
  'guardian abort capacity')
 self.control_commands[#self.control_commands+1]={op='abort',id=w.allocation_generation,reason=reason,started=w.termination_started}
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
  if not wire.busy(self.control_channel) and #self.control_commands>0 then
   wire.enqueue(self.control_channel,self.control_commands); self.control_commands={}
  end
  wire.flush(self.control_channel)
  local control_open=wire.receive(self.control_channel,function(items)
   for _,v in ipairs(items) do
    local w=self.by_id[v.id]
    if w and v.observed_state then
     -- Observation is not bulk application: ready paths/errors remain bulk,
     -- and validated completion cannot make an active execution consumable.
     w.guardian_state=v.observed_state
    end
    if w and v.validated_generation and v.validated_generation==w.execution_generation then
     w.validated_generation=v.validated_generation; w.validated_at=v.result_at
    end
    if w and v.state=='dead' and w.state=='terminating' then
     w.state='dead'; w.process_exit_confirmed=v.process_exit_confirmed
     w.exit_reason=v.exit_reason; w.exit_status=v.exit_status
    end
   end
  end)
  assert(control_open~=false,'guardian control lost')
  wire.flush(self.channel)
  local open=wire.receive(self.channel,function(report,done)
   for _,v in ipairs(report) do
    local w=assert(self.by_id[v.id],'unknown guardian allocation')
    -- An accepted kill/deadline freezes the outcome before its command is sent.
    if not w.dirty and (v.execution_generation==w.execution_generation or v.state=='dead') and (w.state~='dead' or v.state=='dead') and (w.state~='terminating' or v.state=='dead') then
     local failure=w.state=='terminating' and w.failure
     for _,key in ipairs(fields) do
      -- Omitted once-transferred result means no update, not deletion of the
      -- manager-owned outcome. execute owns replacement; public commit owns use.
      if key=='result' then
       if v.result_transfer and v.execution_generation==w.execution_generation then w.result=v.result end
      elseif key~='execution_generation' or v.execution_generation==w.execution_generation then w[key]=v[key] end
     end
     w.failure=failure or w.failure
    end
    if v.result_transfer then
     assert(v.result and math.type(v.execution_generation)=='integer','invalid result transfer')
     self.result_transfers=(self.result_transfers or 0)+1
     -- Safe ownership and intentional stale/active-abort discard both release
     -- the guardian copy. A late ack cannot release a replacement generation.
     assert(#self.control_commands<2*self.control_capacity,'guardian acknowledgement capacity')
     self.control_commands[#self.control_commands+1]={op='ack',id=v.id,generation=v.execution_generation}
    end
    if v.state=='dead' and w.state=='dead' then
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
   end
  end; self.workers=live
  if #self.commands>0 and not wire.busy(self.channel) then
   for _,cmd in ipairs(self.commands) do if cmd.id and self.by_id[cmd.id] then self.by_id[cmd.id].dirty=false end end
   wire.enqueue(self.channel,self.commands); self.commands={}
   wire.flush(self.channel)
  end
  x.p.poll({[self.control_channel.fd]={events={IN=true,OUT=wire.busy(self.control_channel)}},[self.channel.fd]={events={IN=true,OUT=wire.busy(self.channel)}}},delay or 0)
 end)
 if not ok then
  self.closed=true
  x.u.close(self.live); self.live=nil; x.u.close(self.channel.fd); x.u.close(self.control_channel.fd)
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
  if pid==self.guardian_pid then self.closed=true; x.u.close(self.channel.fd); x.u.close(self.control_channel.fd); return true end
  x.p.poll({},5)
 until self.clock()>=deadline
 self.closed=true; x.u.close(self.channel.fd); x.u.close(self.control_channel.fd)
 x.u.write(2,'guardian disposal exit unconfirmed\n'); return false
end
return M
