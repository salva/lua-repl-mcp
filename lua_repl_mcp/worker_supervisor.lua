-- Reusable U4 supervisor. No public session/result-consumption policy lives here.
local x=require('lua_repl_mcp.worker_posix')
local p=require('lua_repl_mcp.worker_protocol')
local c=require('lua_repl_mcp.codec')
local M={}; local S={}; S.__index=S
function M.new(options)
 options=options or {}
 local timeout=options.startup_timeout_ms; if timeout==nil then timeout=30000 end
 assert(type(timeout)=='number' and timeout==timeout and timeout>=1 and timeout<=2147483647 and timeout%1==0,'startup_timeout_ms must be an integer in [1,2147483647]')
 x.s.signal(x.s.SIGPIPE,x.s.SIG_IGN)
 return setmetatable({workers={},generation=0,timeout=timeout/1000,clock=options.clock or x.now,
  interpreter=options.interpreter or 'lua5.4',launch=options.launch},S)
end
local function close(w)
 for _,key in ipairs({'read_fd','write_fd'}) do if w[key] then x.u.close(w[key]); w[key]=nil end end
 w.pending=''; w.buffer=''
end
function S:abort(w,reason)
 if w.state=='terminating' or w.state=='dead' then return end
 w.failure=reason; w.state='terminating'; w.files_complete=false
 close(w); if w.pid then x.s.kill(w.pid,x.s.SIGKILL) end
end
function S:allocate(options)
 options=options or {}
 for k,v in pairs(options) do
  assert((k=='cwd' or k=='stdin_path' or k=='stdout_path' or k=='stderr_path') and type(v)=='string' and not v:find('\0',1,true),'invalid creation option')
 end
 self.generation=self.generation+1
 local w={allocation_generation=self.generation,state='starting',created_paths={},files_complete=false,
  deadline=self.clock()+self.timeout,buffer='',pending='',execution_generation=0}
 self.workers[#self.workers+1]=w
 local r,write=x.u.pipe()
 if not r then w.state='dead'; w.failure='spawn_failed'; return w end
 local read,wr=x.u.pipe()
 if not read then x.u.close(r); x.u.close(write); w.state='dead'; w.failure='spawn_failed'; return w end
 for _,fd in ipairs({r,write,read,wr}) do x.clo(fd,true) end
 local pid=x.u.fork()
 if pid==0 then
  local ok=pcall(function()
  -- Avoid overlapping 0/1/2 even if caller started with closed standard FDs.
  local a=assert(x.f.fcntl(r,x.f.F_DUPFD,3)); local b=assert(x.f.fcntl(wr,x.f.F_DUPFD,3))
  x.close_except(a,b); x.clo(a,false); x.clo(b,false)
  local fd=x.f.open('/dev/null',x.f.O_RDWR)
  if not fd then x.u._exit(126) end
  for n=0,2 do assert(x.u.dup2(fd,n)) end
  if fd>2 then x.u.close(fd) end
  if self.launch then self.launch(a,b,w.allocation_generation,options); x.u._exit(0) end
  local script="package.path="..string.format('%q',package.path)..";package.cpath="..string.format('%q',package.cpath)..";require('lua_repl_mcp.worker_main').main("..a..","..b..","..w.allocation_generation..",assert(require('lua_repl_mcp.codec').decode("..string.format('%q',assert(c.encode(options)))..")))"
  x.u.execp(self.interpreter,{'-e',script})
  x.write_all(b,assert(p.encode(p.record('startup_error',w.allocation_generation,{reason='spawn_failed',message='worker exec failed'}))))
  x.u._exit(127)
  end)
  x.u._exit(ok and 0 or 126)
 end
 x.u.close(r); x.u.close(wr)
 if not pid then x.u.close(read); x.u.close(write); w.state='dead'; w.failure='spawn_failed'; return w end
 w.pid=pid; w.read_fd=read; w.write_fd=write
 x.nonblock(read); x.nonblock(write)
 return w
end
function S:execute(w,input)
 if w.state~='idle' then return nil,'worker not idle' end
 -- Validate the direct evaluator arguments before dispatch.
 local args,e=require('lua_repl_mcp.contracts').validate('repl_execute',input)
 if not args then return nil,e end
 local generation=w.execution_generation+1
 local text,err=p.encode(p.record('execute',w.allocation_generation,{execution_generation=generation,input=input}))
 if not text then return nil,err end
 w.execution_generation=generation; w.result=nil; w.state='running'; w.pending=text; w.offset=1
 return generation
end
function S:graceful_close(w)
 if w.state~='idle' then return nil,'worker not idle' end
 w.pending=assert(p.encode(p.record('close',w.allocation_generation))); w.offset=1; w.state='closing'; return true
end
function S:receive(w,v)
 if w.state=='terminating' or w.state=='dead' then return end
 if v.allocation_generation~=w.allocation_generation then return self:abort(w,'handshake_failed') end
 if w.state=='starting' then
  if v.type=='file_created' then
   if v.path:sub(1,1)~='/' then return self:abort(w,'handshake_failed') end
   for _,path in ipairs(w.created_paths) do if path==v.path then return self:abort(w,'handshake_failed') end end
   w.created_paths[#w.created_paths+1]=v.path
  elseif v.type=='ready' then w.state='idle'; w.files_complete=true
  elseif v.type=='startup_error' then w.startup_message=v.message; self:abort(w,v.reason)
  else self:abort(w,'handshake_failed') end
 elseif w.state=='running' and v.type=='result' and v.execution_generation==w.execution_generation then
  w.result=v.result; w.state='idle'
 else self:abort(w,'corrupt_worker') end
end
function S:drain(w)
 local budget=256*1024
 while w.read_fd and budget>0 do
  local text,_,err=x.u.read(w.read_fd,math.min(65536,budget))
  if not text then if x.retryable(err) then return end; return self:abort(w,'transport_failed') end
  if text=='' then w.eof=true; return end
  budget=budget-#text
  -- Check length before adding an unbounded incomplete frame.
  local rest=text
  while w.read_fd do
   local nl=rest:find('\n',1,true)
   local part=nl and rest:sub(1,nl-1) or rest
   if #w.buffer+#part>p.max_frame then return self:abort(w,'corrupt_worker') end
   w.buffer=w.buffer..part
   if not nl then break end
   local v=p.decode(w.buffer); w.buffer=''
   if not v then return self:abort(w,'corrupt_worker') end
   self:receive(w,v); rest=rest:sub(nl+1)
   if rest=='' then break end
  end
 end
end
function S:step(timeout_ms)
 local poll={}; local now=self.clock(); local delay=timeout_ms or 0
 for _,w in ipairs(self.workers) do
  if w.state=='starting' then
   if now>=w.deadline then self:abort(w,'startup_timeout') else delay=math.min(delay,math.max(0,math.ceil((w.deadline-now)*1000))) end
  end
  if w.read_fd then poll[w.read_fd]={events={IN=true}} end
  if w.write_fd and #w.pending>0 then poll[w.write_fd]={events={OUT=true}} end
 end
 x.p.poll(poll,delay)
 for _,w in ipairs(self.workers) do
  if w.state=='starting' and self.clock()>=w.deadline then self:abort(w,'startup_timeout') end
  if w.read_fd then self:drain(w) end
  if w.write_fd and #w.pending>0 then
   local n,_,err=x.u.write(w.write_fd,w.pending:sub(w.offset,w.offset+65535))
   if n and n>0 then w.offset=w.offset+n; if w.offset>#w.pending then w.pending=''; w.offset=1 end
   elseif not x.retryable(err) then self:abort(w,'transport_failed') end
  end
  if w.pid and not w.reaped then
   local pid,why,status=x.w.wait(w.pid,x.w.WNOHANG)
   if pid==w.pid then
    w.reaped=true; w.exit_reason=why; w.exit_status=status
    -- Drain already available data before recording exit; U6 owns full races.
    if w.read_fd then self:drain(w) end
    if not w.failure and w.state~='closing' then w.failure=w.state=='starting' and 'handshake_failed' or 'worker_exited' end
    if w.state=='starting' then w.files_complete=false end
    close(w); w.state='dead'
   elseif not pid then self:abort(w,'wait_failed') end
  end
  if w.eof and w.state~='dead' and w.state~='closing' then self:abort(w,w.state=='starting' and 'handshake_failed' or 'transport_failed') end
 end
end
-- Provisional U3-style bounded confirmed-reap cleanup; event-loop step is reusable.
function S:shutdown(timeout)
 for _,w in ipairs(self.workers) do self:abort(w,'shutdown') end
 local deadline=x.now()+(timeout or 3)
 repeat
  self:step(5)
  local done=true
  for _,w in ipairs(self.workers) do if w.pid and not w.reaped then done=false end end
  if done then return true end
 until x.now()>=deadline
 return nil,'unconfirmed worker exit'
end
return M
