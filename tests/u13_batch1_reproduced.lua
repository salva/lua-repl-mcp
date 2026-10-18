-- Preserved red-stage reproducer, followed by affected-path boundary gates.
package.path=os.getenv('U9_INSTALLED_LUA_PATH') or './?.lua;./?/init.lua'
package.cpath=''
local codec=require('lua_repl_mcp.codec')
local manager=require('lua_repl_mcp.manager')
local protocol=require('lua_repl_mcp.protocol')
local failures=0
local function check(name,f)
 local ok,e=pcall(f); print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(e)))
 if not ok then failures=failures+1 end
end
local function fixture()
 local now=0
 local b={clock=function() return now end,cwd='/fixture'}
 function b:allocate() return {state='idle'} end
 function b:execute(w) w.state='running'; return 1 end
 function b:abort(w,cause) w.state='terminating'; w.failure=cause end
 function b:step() end
 local m=manager.new{supervisor=b}
 local id=assert(m:commit(m:accept('session_create',{}),function() return true end)).session_id
 return m,id,function(t) now=t end
end
check('false_invalid_request_not_parse_error',function()
 local p=protocol.new{}
 for _,s in ipairs({'null','0','"x"','[]','{}'}) do assert(p:handle(s).error.code==-32600,s) end
 assert(p:handle('{').error.code==-32700)
 local r=p:handle('false'); print('OBS false code='..r.error.code); assert(r.error.code==-32600)
end)
for _,after in ipairs({false,true}) do
 check('fatal_vs_expired_wait_after='..tostring(after),function()
  local m,id,time=fixture()
  local r=m:accept('session_execute',{session_id=id,code='',wait_timeout_ms=1})
  local w=m:accept('session_wait',{session_id=id,wait_timeout_ms=1})
  if after then time(.002); assert(m:preview(r).status=='running') end
  local s=r.session; m:terminate(s,'worker_exited'); time(.003)
  s.worker.state='dead'; s.worker.process_exit_confirmed=true; m:refresh()
  for _,q in ipairs({r,w}) do
   local v=m:preview(q); print('OBS wait status='..tostring(v and v.status)..' error='..tostring(v and v.error and v.error.code))
   assert(v and v.error and v.error.code=='worker_exited')
  end
 end)
end
check('completed_cancel_keeps_ID_until_enqueue',function()
 local m,id=fixture()
 local r=m:accept('session_execute',{session_id=id,code='',wait_timeout_ms=100},'owned')
 local s=r.session; s.worker.result={status='completed',values=codec.array({42})}; s.worker.result_at=0; s.worker.state='idle'; m:refresh()
 assert(m.requests.owned==r); assert(not m:cancel('owned'))
 print('OBS completed cancellation reservation='..tostring(m.requests.owned==r))
 assert(m.requests.owned==r)
end)
check('import_without_debug',function()
 package.loaded['lua_repl_mcp.evaluator']=nil
 local saved=debug; debug=nil
 local ok,v=pcall(require,'lua_repl_mcp.evaluator'); debug=saved
 print('OBS import ok='..tostring(ok)..' result='..tostring(v)); assert(ok)
end)
check('failing_traceback_preserves_original_and_recovers',function()
 package.loaded['lua_repl_mcp.evaluator']=nil
 local saved=debug; debug={traceback=function() error('traceback-broken') end}
 local e=require('lua_repl_mcp.evaluator'); debug=saved
 local r=e.execute{code='error("original-marker")'}
 print('OBS error message='..tostring(r.error and r.error.message))
 assert(r.error and r.error.message:find('original-marker',1,true))
 assert(e.execute{code='return 42'}.values[1]==42)
end)
check('duplicate_dispatch_running_completed_enqueue_reuse',function()
 local m,id=fixture()
 local transport=require('lua_repl_mcp.client_transport').new(m,{})
 local calls=0
 local p=protocol.new{
  names={session_execute=true},tools=codec.array({}),
  outstanding=function(key) return m.requests[key]~=nil end,
  submit=function(key,tool,args) calls=calls+1; transport:submit(key,tool,args) end,
 }
 local init='{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}'
 assert(p:handle(init).result)
 p:handle('{"jsonrpc":"2.0","method":"notifications/initialized"}')
 transport:submit('owned','session_execute',{session_id=id,code='',wait_timeout_ms=100})
 local r=m.requests.owned; local s=r.session
 local function duplicates()
  for _,method in ipairs({'ping','initialize','tools/list','tools/call','unknown'}) do
   local v=p:handle(assert(codec.encode{jsonrpc='2.0',id='owned',method=method,params={name='session_execute',arguments={code=''}}}))
   assert(v.error.code==-32600 and v.id==require('lua_repl_mcp').null)
   assert(m.requests.owned==r and s.worker.state~='terminating')
  end
  assert(calls==0)
  local n=#transport.pending
  transport:submit('owned','session_kill',{session_id=id})
  assert(#transport.pending==n and m.requests.owned==r)
  local v=assert(codec.decode(transport.queue[#transport.queue].text))
  assert(v.error.code==-32600 and v.id==require('lua_repl_mcp').null)
 end
 duplicates()
 s.worker.result={status='completed',values=codec.array({42})}; s.worker.result_at=0; s.worker.state='idle'; m:refresh()
 assert(not m:cancel('owned')); duplicates()
 assert(not m:commit(r,function() return false end)); assert(m.requests.owned==r)
 assert(not m:commit(r,function() error('enqueue failed') end)); assert(m.requests.owned==r)
 assert(m:commit(r,function() return true end).values[1]==42); assert(not m.requests.owned)
 assert(p:handle('{"jsonrpc":"2.0","id":"owned","method":"ping"}').result)
 transport:submit('owned','session_execute',{session_id=id,code='',wait_timeout_ms=100})
 assert(m.requests.owned~=r and m:cancel('owned') and not m.requests.owned)
end)
check('fatal_zero_wait_and_committed_pending',function()
 for _,committed in ipairs({false,true}) do
  local m,id,time=fixture()
  local r=m:accept('session_execute',{session_id=id,code='',wait_timeout_ms=0})
  if committed then assert(m:commit(r,function() return true end).status=='running') end
  m:terminate(r.session,'execution_timeout')
  assert(not m:preview(r)) -- cleanup still in progress (or already committed)
  r.session.worker.state='dead'; r.session.worker.process_exit_confirmed=true; m:refresh()
  if committed then assert(not m:preview(r))
  else assert(m:preview(r).error.code=='execution_timeout') end
 end
end)
check('missing_debug_runtime_error_and_recovery',function()
 package.loaded['lua_repl_mcp.evaluator']=nil
 local saved=debug; debug=nil
 local e=require('lua_repl_mcp.evaluator'); debug=saved
 local r=e.execute{code='error("no-debug-original")'}
 assert(r.error.code=='lua_runtime_error' and r.error.execution_state=='started')
 assert(r.error.message:find('no-debug-original',1,true) and not r.error.traceback)
 assert(e.execute{code='return 1.5,nil,42'}.values[3]==42)
end)
print('TOTAL failures='..failures)
os.exit(failures==0 and 0 or 1)
