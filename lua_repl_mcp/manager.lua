-- Connection-local policy above the private supervisor. No MCP or native imports
-- until new() needs the default backend. Request handles are internal, not IDs.
local contracts=require('lua_repl_mcp.contracts')
local codec=require('lua_repl_mcp.codec')
local errors=require('lua_repl_mcp.errors')
local null=require('lua_repl_mcp').null
local M={}; local C={}; C.__index=C
local serial=0
local function failure(code,state)
 local stage=(code=='unknown_session' or code=='session_busy' or code=='session_terminating' or
  code=='no_execution' or code=='result_unavailable') and 'validation' or 'execution'
 return {error=errors.new(code,code,stage,state or 'not_started')}
end
-- Snapshots isolate manager-owned, already validated JSON data. They are not
-- serialization: applying the public wire budget here would raise before the
-- transport can preflight a complete response and preserve an overflowing result.
-- Strings are immutable/shared; only bounded owned table structure is copied.
local function copy(t)
 if type(t)~='table' or t==null then return t end
 local v={}
 for k,value in pairs(t) do v[k]=copy(value) end
 if codec.kind(t)=='array' then codec.array(v)
 elseif codec.kind(t)=='object' then codec.object(v) end
 return v
end
function M.new(o)
 o=o or {}; serial=serial+1
 local admission=require('lua_repl_mcp.limits').admission(o.admission)
 local limits=require('lua_repl_mcp.limits').connection(o.limits)
 local backend=o.supervisor or require('lua_repl_mcp.worker_supervisor').new(o)
 if backend.limits then
  for k,v in pairs(require('lua_repl_mcp.limits').authored(limits)) do
   assert(backend.limits[k]==v,'supervisor conflicts with manager limits')
  end
 end
 return setmetatable({backend=backend,clock=o.clock or backend.clock,
  limits=limits,limit_options=o.limits and require('lua_repl_mcp.limits').authored(limits),admission=admission,slots={ordinary=0,control=0,kill=0},requests={},sessions={},order={},starting={},next_id=0,prefix='session-'..serial..'-',closed=false},C)
end
function C:allocate(options)
 if #self.order>=self.admission.sessions then return nil end
 self.next_id=self.next_id+1
 local id=self.prefix..self.next_id
 local s={limits=self.limits,id=id,worker=self.backend:allocate(options or {}),generation=0,
  cwd=(options or {}).cwd or (self.backend.cwd or require('posix.unistd').getcwd())}
 self.sessions[id]=s; self.order[#self.order+1]=s
 return s
end
local function envelope(s,r)
 local v=copy(r); v.session_id=s.id
 v.session_status=s.worker.state=='dead' and 'terminated' or s.worker.state
 v.session_usable=s.worker.state=='idle' or s.worker.state=='running'
 return v
end
function C:dispatch(s,a,r)
 if s.worker.state~='idle' then
  r.response=envelope(s,failure(s.worker.state=='terminating' and 'session_terminating' or 'session_busy'))
  if s.execution then r.response.status=s.execution.status end
  return
 end
 -- Reserve policy before backend execute can arm its bounded command write.
 local old=s.execution
 local e={generation=s.generation+1,status='running',dispatch_at=self.clock()}
 if a.execution_timeout_ms~=null then e.deadline=e.dispatch_at+a.execution_timeout_ms/1000 end
 s.execution=e; s.generation=e.generation; r.execution=e
 if a.wait_timeout_ms~=null then r.deadline=e.dispatch_at+a.wait_timeout_ms/1000 end
 local generation,err=self.backend:execute(s.worker,{code=a.code,args=a.args},e.deadline,r.original)
 if not generation then
  s.execution=old; s.generation=s.generation-1; r.execution=nil
  r.response=envelope(s,failure('transport_error')); return
 end
 if old then old.payload=nil; old.replaced=true end
 -- Zero execution is acceptance, even when a backend completes immediately.
 if a.wait_timeout_ms==0 then r.response=envelope(s,{status='running'}) end
end
-- Slots belong to opaque handles, not just JSON-RPC IDs. Release exactly once
-- on cancellation or commitment, including commits that immediately disconnect.
function C:release(r)
 if r.slot and not self.closed then self.slots[r.slot]=self.slots[r.slot]-1; r.slot=nil end
end
function C:admit(r,tool)
 local slot='ordinary'
 if tool=='session_list' or tool=='session_kill' or tool=='ping' then
  if self.slots.control<self.admission.control-self.admission.kill_reserve then slot='control'
  elseif tool=='session_kill' and self.slots.kill<self.admission.kill_reserve then slot='kill'
  else return false end
 elseif self.slots.ordinary>=self.admission.ordinary then return false end
 self.slots[slot]=self.slots[slot]+1; r.slot=slot; return true
end
function C:accept(tool,input,request_id,original)
 assert(not self.committing,'response commit must not reenter manager')
 self:refresh()
 local a,err=contracts.validate(tool,input,{max_depth=self.limits.max_depth,max_bytes=not original and self.limits.input_bytes or math.huge})
 local r={tool=tool,accepted_at=self.clock(),original=original}
 if not self:admit(r,tool) then
  r.admission_rejected=true; r.response=failure('limit_exceeded'); return r
 end
 if request_id~=nil then self:bind(request_id,r) end
 if a and tool~='session_create' and tool~='session_execute' and tool~='session_wait' and tool~='session_list' and tool~='session_kill' then
  r.response={error=errors.new('invalid_arguments','unknown manager tool','validation','not_started')}; return r
 end
 if not a then r.response={error=err}; return r end
 if self.closed then r.response=failure('unknown_session'); return r end
 if tool=='session_list' then
  local entries=codec.array({})
  for _,s in ipairs(self.order) do
   if self.sessions[s.id] then
    local e=s.execution
    entries[#entries+1]={session_id=s.id,session_status=s.worker.state,
     execution_status=e and e.status or 'none',result_available=e~=nil and e.payload~=nil,cwd=s.cwd}
   end
  end
  r.response={sessions=entries}; return r
 end
 local s
 if tool=='session_create' or (tool=='session_execute' and a.session_id==null) then
  s=self:allocate(tool=='session_create' and a or a.create_options)
  if not s then r.response=failure('limit_exceeded'); return r end
  r.creation=true
 else s=self.sessions[a.session_id] end
 if not s then
  r.response=failure('unknown_session'); r.response.session_id=a.session_id; r.response.session_usable=false; return r
 end
 r.session=s
 if tool=='session_create' then r.starting=true
 elseif tool=='session_execute' then
  if r.creation and s.worker.state=='starting' then r.starting=true; r.input=a
  else self:dispatch(s,a,r) end
 elseif tool=='session_wait' then
  r.execution=s.execution
  if not r.execution then r.response=envelope(s,failure('no_execution'))
  elseif a.wait_timeout_ms~=null then r.deadline=r.accepted_at+a.wait_timeout_ms/1000 end
 elseif tool=='session_kill' then
  self:terminate(s,'session_killed'); r.killing=true
 end
 if r.starting then self.starting[#self.starting+1]=r end
 return r
end
-- All destructive paths freeze only a still-active generation. The backend owns
-- signals, descriptors and bounded reaping; policy waits for its terminal state.
function C:freeze(s,cause)
 local e=s.execution
 if e and e.status=='running' then
  e.status='failed'; e.fatal=true
  e.payload=failure(cause,'started'); e.payload.status=e.status
  e.completed_at=self.clock(); e.deadline=nil; e.cleanup=true
 end
end
function C:terminate(s,cause)
 self:freeze(s,cause); self.backend:abort(s.worker,cause)
end
function C:exit_info(v,w)
 if v.error then
  if w.exit_reason=='exited' then v.error.exit_code=w.exit_status
  elseif w.exit_reason=='killed' then v.error.signal=w.exit_status end
 end
 v.process_exit_confirmed=w.process_exit_confirmed==true or w.reaped==true
 if not v.process_exit_confirmed then
  v.notice='Worker exit was not confirmed; external side effects may continue. Descendant termination is not guaranteed.'
 end
end
-- Internal adapter seam: bind before any response can commit. IDs retain JSON
-- type identity. Completed/answered/cancelled IDs are inert, never retargeted.
function C:bind(id,r)
 assert(type(id)=='string' or type(id)=='number','invalid request ID')
 assert(not self.requests[id] and not r.request_id,'request already bound')
 self.requests[id]=r; r.request_id=id; return r
end
function C:cancel(id)
 assert(not self.committing,'response commit must not reenter manager')
 self:refresh()
 local r=self.requests[id]
 if not r or r.done or r.cancelled then return false end
 local e=r.execution
 -- A recorded result is completed even if its response has not committed yet.
 if not r.starting and not r.killing and (e and e.status~='running') then
  return false
 end
 self.requests[id]=nil; r.cancelled=true; self:release(r)
 if r.session and not r.killing then
  if r.starting then r.starting=nil; r.input=nil end
  self:terminate(r.session,'request_cancelled')
 end
 return true
end
function C:refresh()
 for _,s in ipairs(self.order) do
  if self.sessions[s.id] then
   local w=s.worker; local e=s.execution
   if w.cwd then s.cwd=w.cwd end
   if e and e.status=='running' and w.result then
    local received=w.result_at or self.clock()
    if not e.deadline or received<e.deadline then
     e.payload=w.result; e.status=w.result.status; e.completed_at=received; e.deadline=nil
    else self:terminate(s,'execution_timeout') end
    w.result=nil
   end
   -- The guardian validates worker records and enforces the dispatch deadline
   -- independently. A running mirror is not evidence of a still-active worker.
   -- Other backends retain the original manager clock arbitration.
   if not self.backend.owns_execution_deadlines and e and e.status=='running' and e.deadline and self.clock()>=e.deadline then self:terminate(s,'execution_timeout') end
   if e and e.status=='running' and (w.state=='terminating' or w.state=='dead') then
    self:freeze(s,w.failure=='execution_timeout' and 'execution_timeout' or (w.failure=='worker_exited' and 'worker_exited' or 'transport_error'))
   end
   if w.state=='dead' then
    if e then
     if e.status=='running' then self:freeze(s,'worker_exited') end
     e.terminated=true
     if e.cleanup then self:exit_info(e.payload,w); e.cleanup=nil end
    end
    self.sessions[s.id]=nil
   end
  end
 end
 -- Drop dead sessions from listing storage; request handles alone retain old generations.
 local live={}; for _,s in ipairs(self.order) do if self.sessions[s.id] then live[#live+1]=s end end
 self.order=live
 -- Allocation completion must dispatch even if the transport has not asked for
 -- a preview yet. Otherwise an accepted implicit execution could never run.
 local pending=self.starting; self.starting={}
 for _,r in ipairs(pending) do
  self:preview(r)
  if r.starting then self.starting[#self.starting+1]=r end
 end
end
function C:step(ms)
 assert(not self.committing,'response commit must not reenter manager')
 local delay=ms or 0
 self:refresh()
 for _,s in ipairs(self.order) do
  local e=s.execution
  if not self.backend.owns_execution_deadlines and e and e.deadline then delay=math.min(delay,math.max(0,math.ceil((e.deadline-self.clock())*1000))) end
 end
 self.backend:step(delay); self:refresh()
end
-- Inspecting a response never claims a payload. A stale preview must not be sent:
-- commit() rechecks generation availability at the transmission boundary.
function C:preview(r)
 if r.done then return nil,'request already committed' end
 local s=r.session
 if r.cancelled then return nil,'request cancelled' end
 if r.killing then
  if s.worker.state~='dead' then return nil end
  local v=envelope(s,{status='killed'}); self:exit_info(v,s.worker); return v
 end
 if r.starting then
  local state=s.worker.state
  if state=='starting' or state=='terminating' then return nil end
  r.starting=nil
  if state~='idle' then
   local reason=s.worker.failure
   local allowed={startup_timeout=true,spawn_failed=true,cwd_setup_failed=true,stdio_setup_failed=true,handshake_failed=true}
   if not allowed[reason] then reason='handshake_failed' end
   r.response={error=errors.new('session_creation_error',s.worker.startup_message or s.worker.failure or 'spawn_failed',
    'creation','not_started',{reason=reason},self.limits.diagnostic_bytes)}
   r.response.error.created_files=codec.array(s.worker.created_paths or {})
   r.response.error.created_files_complete=s.worker.files_complete or false
   self:exit_info(r.response,s.worker)
  elseif r.input then self:dispatch(s,r.input,r)
  else r.response={session_id=s.id,session_status='idle'} end
 end
 local e=r.execution
 -- Recorded fatal outcomes supersede pending replies until commitment,
 -- including the explicit zero-wait acceptance snapshot.
 if r.response and not (e and e.fatal) then return copy(r.response) end
 if not e then return nil end
 if e.cleanup then return nil end
 -- A late observation of a terminal result must not extend a finite wait.
 if not e.fatal and r.deadline and self.clock()>=r.deadline and
    (not e.completed_at or e.completed_at>r.deadline) then
  return envelope(s,{status='running'})
 end
 if e.status~='running' then
  if e.payload then return envelope(s,e.payload),e end
  local v=envelope(s,failure('result_unavailable','completed')); v.status=e.status; return v
 end
 if e.replaced then
  local v=envelope(s,failure('result_unavailable','started')); v.status=e.status; return v
 end
 if r.deadline and self.clock()>=r.deadline then return envelope(s,{status='running'}) end
 return nil
end
-- send is the U7/U8 boundary: budget-check and atomically enqueue this exact
-- response, returning true ONLY on committed transmission. No coroutine yield
-- or manager reentry is allowed. A rejected/failed send consumes nothing.
function C:commit(r,send)
 assert(not self.committing,'response commit must not reenter manager')
 local response,e=self:preview(r)
 if not response then return nil,e end
 self.committing=true
 local ok,accepted=pcall(send,response)
 self.committing=false
 if not ok then return nil,accepted end
 if not accepted then return nil,'response not committed' end
 r.done=true; self:release(r)
 if r.request_id~=nil then self.requests[r.request_id]=nil end
 if e then e.payload=nil; e.consumed=true end
 return response
end
function C:disconnect()
 assert(not self.committing,'response commit must not reenter manager')
 self.closed=true
 self.slots={ordinary=0,control=0,kill=0}
 for _,r in pairs(self.requests) do r.cancelled=true end
 self.requests={}
 for _,s in ipairs(self.order) do
  if s.execution then s.execution.payload=nil end
 end
 self.sessions={}; self.order={}; self.starting={}
 return self.backend:shutdown()
end
return M
