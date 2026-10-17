local c=require('lua_repl_mcp.codec')
local x=require('lua_repl_mcp.worker_posix')
local S=require('lua_repl_mcp.worker_supervisor')
local manager=require('lua_repl_mcp.manager')
local bad=0
local function check(name,fn) local ok,e=pcall(fn);print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(e)));if not ok then bad=bad+1 end end
local function fixture(options)
 local b=(os.getenv('U13_GUARDIAN') and not (options and options.launch)) and require('lua_repl_mcp.guardian').new(options) or S.new(options);local m=manager.new{supervisor=b}
 return m,b
end
local function finish(m,r)
 local until_at=x.now()+8
 repeat m:step(5);local v=m:preview(r);if v then return v end until x.now()>=until_at
 error('fixture deadline')
end
for _,case in ipairs({{name='bad_cwd',input={cwd='/nonexistent-batch1-path'},reason='cwd_setup_failed'},{name='bad_stdio',input={stdin_path='/nonexistent-batch1-path'},reason='stdio_setup_failed'}}) do
 local m,b=fixture()
 check('F07 '..case.name,function()
  local v=finish(m,m:accept('session_create',case.input));print('OBS '..case.name..' '..assert(c.encode(v)))
  assert(v.error.reason==case.reason,'wrong reason '..tostring(v.error.reason))
  assert(v.error.stage=='creation' and #v.error.message<=m.limits.diagnostic_bytes)
  assert(v.error.message:find('nonexistent',1,true),'startup diagnostic lost')
 end)
 b:shutdown()
end
do
 local m,b=fixture{launch=function() end}
 check('F07 startup_eof',function()
  local v=finish(m,m:accept('session_create',{})); print('OBS '..assert(c.encode(v))); assert(v.error.reason=='handshake_failed')
 end);b:shutdown()
end
for _,case in ipairs({{name='exit7',code='os.exit(7)',field='exit_code',value=7},{name='signal9',code="local s=require('posix.signal');s.kill(require('posix.unistd').getpid(),s.SIGKILL)",field='signal',value=9}}) do
 local m,b=fixture()
 check('F07 '..case.name,function()
  local cr=m:accept('session_create',{});local created=finish(m,cr)
  assert(created.session_id);m:commit(cr,function() return true end)
  local r=m:accept('session_execute',{session_id=created.session_id,code=case.code,wait_timeout_ms=require('lua_repl_mcp').null})
  local v=finish(m,r)
  print('OBS '..case.name..' public='..assert(c.encode(v))..' observed='..tostring(r.session.worker.exit_reason)..'/'..tostring(r.session.worker.exit_status))
  assert(r.session.worker.exit_status==case.value)
  assert(v.error and v.error[case.field]==case.value,'observed termination fields missing')
 end);b:shutdown()
end
do
 local m,b=fixture()
 check('F06 worker-local preparation witness and usable session',function()
  local cr=m:accept('session_create',{});local v=finish(m,cr);m:commit(cr,function() return true end)
  -- Isolate preparation from the separately owned batch2 large-input relay.
  local code=[=[local c=require('lua_repl_mcp.codec');local args=c.array({})
   for i=1,1000000 do args[i]=0 end
   local r=require('lua_repl_mcp.evaluator').execute{code='_G.oversize_witness=true',args=args}
   return r.error.code,r.error.stage,r.error.execution_state,_G.oversize_witness==nil]=]
  local r=m:accept('session_execute',{session_id=v.session_id,code=code,wait_timeout_ms=require('lua_repl_mcp').null})
  local result=finish(m,r)
  assert(result.values and result.values[1]=='limit_exceeded' and result.values[2]=='execution' and result.values[3]=='not_started' and result.values[4])
  m:commit(r,function() return true end)
  local recovery=m:accept('session_execute',{session_id=v.session_id,code='return _G.oversize_witness==nil,42',wait_timeout_ms=require('lua_repl_mcp').null})
  local success=finish(m,recovery);assert(success.values[1] and success.values[2]==42 and success.session_usable)
 end);b:shutdown()
end
for _,case in ipairs({
 {reason='spawn_failed',options={interpreter='/nonexistent-batch1-interpreter'}},
 {reason='startup_timeout',options={startup_timeout_ms=10,launch=function() x.p.poll({},2000) end}}
}) do
 local m,b=fixture(case.options)
 check('F07 '..case.reason,function()
  local v=finish(m,m:accept('session_create',{}))
  assert(v.error.reason==case.reason and v.error.stage=='creation')
  assert(v.process_exit_confirmed and #v.error.message<=m.limits.diagnostic_bytes)
 end);b:shutdown()
end
print('TOTAL native failures='..bad);os.exit(bad==0 and 0 or 1)
