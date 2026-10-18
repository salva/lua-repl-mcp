local supervisor=require('lua_repl_mcp.worker_supervisor')
local x=require('lua_repl_mcp.worker_posix')
local p=require('lua_repl_mcp.worker_protocol')
local c=require('lua_repl_mcp.codec')
local stat=require('posix.sys.stat')
local dir=assert(os.getenv('U4_DIR'))
local owners={}; local count=0
local function new(options) local s=supervisor.new(options); owners[#owners+1]=s; return s end
local function until_(s,predicate)
 local deadline=x.now()+5
 repeat s:step(5); if predicate() then return end until x.now()>deadline
 error('fixture deadline')
end
local function ready(s,opts)
 local w=s:allocate(opts); until_(s,function() return w.state~='starting' end)
 assert(w.state=='idle',tostring(w.failure)..': '..tostring(w.startup_message)); return w
end
local function execute(s,w,code)
 assert(s:execute(w,{code=code})); until_(s,function() return w.state~='running' end)
 assert(w.state=='idle',w.failure); return w.result
end
local function reap(s,w) until_(s,function() return w.reaped end); assert(not x.w.wait(w.pid,x.w.WNOHANG)) end
local function read(path) local f=assert(io.open(path,'rb')); local v=f:read('a'); f:close(); return v end
local function put(path,text) local f=assert(io.open(path,'wb')); f:write(text); f:close() end
local function test(name,fn)
 fn(); count=count+1; print('PASS '..name)
 for _,s in ipairs(owners) do assert(s:shutdown()) end
 owners={}
end
local function fixture(fn,timeout)
 return new({startup_timeout_ms=timeout or 2000,launch=function(a,b,g,o)
  x.clo(a,true); x.clo(b,true); fn(a,b,g,o)
 end})
end
local function send(fd,kind,g,extra) assert(x.write_all(fd,assert(p.encode(p.record(kind,g,extra))))) end
local function block(a) while true do local t,_,e=x.u.read(a,1); if t=='' then return end; assert(t or e==x.e.EINTR) end end
local ok,err=xpcall(function()
 test('configuration_and_protocol_bounds',function()
  for _,v in ipairs({0,-1,1.5,math.huge,0/0,2147483648,false,'30'}) do
   assert(not pcall(supervisor.new,{startup_timeout_ms=v}),tostring(v))
  end
  assert(supervisor.new().timeout==30)
  assert(not p.decode('{"type":"ready","protocol_version":1,"allocation_generation":1,"extra":1}'))
  assert(not p.decode(string.rep('x',p.max_frame+1)))
  assert(not p.decode('{"type":"ready","protocol_version":2,"allocation_generation":1}'))
 end)
 test('ready_persistent_globals_recoverable_errors_and_wrapper_exit',function()
  local s=new(); local w=ready(s)
  assert(execute(s,w,'counter=(counter or 0)+1; return counter').values[1]==1)
  assert(execute(s,w,'counter=counter+1; error("expected")').status=='failed')
  assert(execute(s,w,'return counter').values[1]==2)
  assert(s:graceful_close(w)); reap(s,w)
  assert(w.exit_reason=='exited' and w.exit_status==0 and not w.failure)
 end)
 test('cwd_relative_shared_exclusive_permissions_stdin_native_subprocess',function()
  put(dir..'/input','hello\n')
  local s=new(); local w=ready(s,{cwd=dir,stdin_path='input',stdout_path='shared',stderr_path='shared'})
  assert(w.files_complete and #w.created_paths==1 and w.created_paths[1]==dir..'/shared')
  assert((stat.stat(dir..'/shared').st_mode & tonumber('777',8))==tonumber('600',8))
  local r=execute(s,w,[[print('lua'); io.stderr:write('err\n'); require('posix.unistd').write(1,'native\n'); os.execute('printf subprocess'); io.stdout:flush(); io.stderr:flush(); return io.read('*l')]])
  assert(r.values[1]=='hello')
  assert(execute(s,w,[[print('again'); io.stdout:flush(); return io.read('*l')]]).values[1]==require('lua_repl_mcp').null)
  local text=read(dir..'/shared'); for _,v in ipairs({'lua','err','native','subprocess','again'}) do assert(text:find(v,1,true),text) end
  s:abort(w,'done'); reap(s,w)
  local bad=s:allocate({cwd=dir,stdout_path='shared'}); reap(s,bad)
  assert(bad.failure=='stdio_setup_failed' and #bad.created_paths==0 and read(dir..'/shared')==text)
 end)
 test('umask_defaults_and_distinct_outputs',function()
  local old=stat.umask(tonumber('077',8))
  local s=new(); local w=s:allocate({cwd=dir,stdout_path='separate_out',stderr_path='separate_err'})
  stat.umask(old)
  until_(s,function() return w.state~='starting' end); assert(w.state=='idle',w.failure)
  assert(#w.created_paths==2)
  assert((stat.stat(dir..'/separate_out').st_mode & tonumber('777',8))==tonumber('600',8))
  execute(s,w,[[io.write('stdout'); io.stderr:write('stderr'); io.stdout:flush(); io.stderr:flush()]])
  assert(read(dir..'/separate_out')=='stdout' and read(dir..'/separate_err')=='stderr')
  w=ready(s)
  assert(execute(s,w,[[print('discarded'); io.stderr:write('discarded'); io.stdout:flush(); io.stderr:flush(); return io.read('*a')]]).values[1]=='')
 end)
 test('exec_cwd_open_failures_and_retained_artifact',function()
  local s=new({interpreter='/absent/u4-lua'}); local w=s:allocate(); reap(s,w); assert(w.failure=='spawn_failed')
  s=new(); w=s:allocate({cwd=dir..'/absent'}); reap(s,w); assert(w.failure=='cwd_setup_failed',tostring(w.failure))
  w=s:allocate({cwd=dir,stdout_path='retained',stderr_path='absent/file'})
  reap(s,w); assert(w.failure=='stdio_setup_failed' and #w.created_paths==1)
  assert(read(dir..'/retained')=='' and not w.files_complete)
  w=s:allocate({stdin_path=dir..'/absent'}); reap(s,w); assert(w.failure=='stdio_setup_failed')
 end)
 test('fifo_blocked_startup_second_worker_useful_timeout_partial_paths',function()
  assert(stat.mkfifo(dir..'/fifo',tonumber('600',8)))
  local s=new({startup_timeout_ms=4000})
  local blocked=s:allocate({cwd=dir,stdout_path='fifo_partial',stdin_path='fifo'})
  until_(s,function() return #blocked.created_paths==1 end)
  local second=ready(s)
  local f=assert(io.open('/proc/'..blocked.pid..'/wchan')); local where=f:read('a'); f:close()
  assert(where:find('wait_for_partner',1,true),where)
  assert(execute(s,second,'return "useful"').values[1]=='useful')
  assert(blocked.state=='starting')
  reap(s,blocked); assert(blocked.failure=='startup_timeout' and #blocked.created_paths==1 and not blocked.files_complete)
  assert(read(dir..'/fifo_partial')=='')
 end)
 test('death_between_create_and_report_is_honestly_incomplete',function()
  local s=fixture(function(a,b,g)
   local fd=assert(x.f.open(dir..'/unreported',x.f.O_CREAT|x.f.O_EXCL|x.f.O_WRONLY,tonumber('600',8)))
   x.u.close(fd); x.u._exit(17)
  end)
  local w=s:allocate(); reap(s,w)
  assert(w.failure=='handshake_failed' and #w.created_paths==0 and not w.files_complete)
  assert(read(dir..'/unreported')=='')
 end)
 test('partial_frames_death_and_invalid_handshake',function()
  for _,text in ipairs({'{"type":','no json\n','{"type":"ready","protocol_version":7,"allocation_generation":1}\n'}) do
   local s=fixture(function(a,b) assert(x.write_all(b,text)) end)
   local w=s:allocate(); reap(s,w); assert(w.failure and not w.files_complete)
  end
 end)
 test('fragmented_ready_partial_record_timeout_and_abort_late_ready',function()
  local s=fixture(function(a,b,g)
   local text=assert(p.encode(p.record('ready',g)))
   for i=1,#text do assert(x.write_all(b,text:sub(i,i))) end
   block(a)
  end)
  local w=ready(s); s:abort(w,'explicit_abort'); s:receive(w,p.record('ready',w.allocation_generation)); reap(s,w)
  assert(w.failure=='explicit_abort' and w.state=='dead')
  s=fixture(function(a,b,g)
   send(b,'file_created',g,{path=dir..'/known'})
   assert(x.write_all(b,'{"type":"ready"')); block(a)
  end,500)
  w=s:allocate(); reap(s,w); assert(w.failure=='startup_timeout' and #w.created_paths==1 and not w.files_complete)
  -- A complete ready queued before observation is rejected after its allocation deadline.
  s=fixture(function(a,b,g) send(b,'ready',g); block(a) end,500)
  w=s:allocate(); assert(x.p.poll({},800)==0); s:step(0); reap(s,w)
  assert(w.failure=='startup_timeout' and not w.files_complete)
 end)
 test('unknown_stale_duplicate_records_dispose_worker',function()
  for _,kind in ipairs({'unknown','stale_allocation','duplicate_ready','stale_execution'}) do
   local s=fixture(function(a,b,g)
    if kind=='unknown' then x.write_all(b,'{"type":"wat","protocol_version":1,"allocation_generation":1}\n')
    elseif kind=='stale_allocation' then send(b,'ready',g+1)
    elseif kind=='duplicate_ready' then send(b,'ready',g); send(b,'ready',g)
    else
     send(b,'ready',g)
     local buf=''; repeat buf=buf..assert(x.u.read(a,65536)) until buf:find('\n',1,true)
     send(b,'result',g,{execution_generation=2,result={status='completed',values=c.array({99})}})
    end
    block(a)
   end)
   local w=s:allocate()
   if kind=='stale_execution' then until_(s,function() return w.state=='idle' end); assert(s:execute(w,{code='return 1'})) end
   reap(s,w); assert(w.failure and not w.result,kind)
  end
 end)
 test('oversized_transport_frame_disposal_and_fragmented_result',function()
  local s=fixture(function(a,b,g)
   local chunk=string.rep('x',65536)
   for i=1,math.floor(p.max_frame/#chunk)+1 do if not x.write_all(b,chunk) then return end end
  end)
  local w=s:allocate(); reap(s,w); assert(w.failure=='corrupt_worker' and not w.files_complete)
  s=fixture(function(a,b,g)
   send(b,'ready',g)
   local buf=''; repeat buf=buf..assert(x.u.read(a,65536)) until buf:find('\n',1,true)
   local text=assert(p.encode(p.record('result',g,{execution_generation=1,result={status='completed',values=c.array({7})}})))
   for i=1,#text do assert(x.write_all(b,text:sub(i,i))) end
   block(a)
  end)
  w=ready(s); assert(s:execute(w,{code='return 7'}))
  until_(s,function() return w.state~='running' end); assert(w.state=='idle' and w.result.values[1]==7)
 end)
 test('duplicate_result_disposes_without_second_completion',function()
  local s=fixture(function(a,b,g)
   send(b,'ready',g)
   local buf=''; repeat buf=buf..assert(x.u.read(a,65536)) until buf:find('\n',1,true)
   local r={execution_generation=1,result={status='completed',values=c.array({1})}}
   send(b,'result',g,r); send(b,'result',g,r); block(a)
  end)
  local w=ready(s); assert(s:execute(w,{code='return 1'})); reap(s,w)
  assert(w.failure=='corrupt_worker' and w.execution_generation==1)
 end)
 test('independent_exit_monitor_with_descendant_channel_writer',function()
  local s=fixture(function(a,b,g)
   send(b,'ready',g)
   local pid=assert(x.u.fork())
   if pid==0 then x.p.poll({},2000); x.u._exit(0) end
   x.u._exit(0)
  end)
  local w=s:allocate(); local start=x.now(); reap(s,w)
  assert(x.now()-start<1.5 and not w.eof,'exit must not depend on inherited EOF')
 end)
 test('control_cloexec_and_unrelated_inherited_descriptor_closed',function()
  -- Deliberately non-CLOEXEC sentinel from the manager is not inherited.
  local sentinel=assert(x.f.open(dir..'/sentinel',x.f.O_CREAT|x.f.O_WRONLY,tonumber('600',8)))
  local s=new(); local w=ready(s)
  local result=execute(s,w,[[
   local u=require('posix.unistd'); local f=require('posix.fcntl')
   local controls=0
   for fd=3,128 do local flags=f.fcntl(fd,f.F_GETFD); if flags then assert(flags & f.FD_CLOEXEC ~= 0); controls=controls+1 end end
   assert(controls==2,controls)
   local ok=os.execute("sh -c 'for f in /proc/self/fd/*; do case $f in */0|*/1|*/2|*/3) ;; *) exit 19;; esac; done'")
   return ok,controls
  ]])
  x.u.close(sentinel)
  assert(result.status=='completed' and result.values[1]==true and result.values[2]==2)
 end)
 test('bounded_nonblocking_write_and_drain_second_worker',function()
  local s=fixture(function(a,b,g) send(b,'ready',g); x.p.poll({},10000) end)
  local w=ready(s)
  -- Fixture never consumes enough to complete a large frame; manager must not block.
  assert(s:execute(w,{code=string.rep(' ',1024*1024)..'return 1'}))
  local real=new(); local second=ready(real)
  local start=x.now()
  for i=1,40 do s:step(0); real:step(0) end
  assert(x.now()-start<1 and #w.pending>0 and w.offset>1)
  assert(execute(real,second,'return 7').values[1]==7)
 end)
end,debug.traceback)
for _,s in ipairs(owners) do local done,msg=s:shutdown(); if not done then io.stderr:write(tostring(msg),'\n') end end
if not ok then error(err) end
print('PASS U4 '..count..' named real-process groups')
