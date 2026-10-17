-- Real child fault boundaries. Parent owns every fork before setup can fail.
local x=require('lua_repl_mcp.worker_posix')
local S=require('lua_repl_mcp.worker_supervisor')
local p=require('lua_repl_mcp.worker_protocol')
local function await(b,w)
 local deadline=x.now()+5
 repeat b:step(5); assert(x.now()<deadline,'fault cleanup watchdog') until w.state=='dead'
 assert(w.process_exit_confirmed and w.reaped,'child not reaped')
 assert(not w.read_fd and not w.write_fd,'partial channel retained')
 local got,_,errno=x.w.wait(w.pid,x.w.WNOHANG)
 assert(not got and errno==x.e.ECHILD,'child still waitable')
end
for _,point in ipairs{'parent_nonblock','child_setup','ready_delivery','result_delivery'} do
 local options={}
 if point=='child_setup' then options.launch=function() error('injected child setup') end end
 if point=='ready_delivery' then options.launch=function(a,b,id)
  assert(x.write_all(b,'{"type":"ready"')); x.u._exit(8)
 end end
 if point=='result_delivery' then options.launch=function(a,b,id)
  assert(x.write_all(b,assert(p.encode(p.record('ready',id,{cwd='/'})))))
  -- Ready barrier followed by actual execute command before partial result.
  local text=''
  repeat text=text..assert(x.u.read(a,1024)) until text:find('\n',1,true)
  assert(x.write_all(b,'{"type":"result"')); x.u._exit(9)
 end end
 local b=S.new(options)
 local nb=x.nonblock
 if point=='parent_nonblock' then x.nonblock=function() error('injected post-fork setup') end end
 local w=b:allocate{}
 x.nonblock=nb
 if point=='result_delivery' then
  local deadline=x.now()+5
  repeat b:step(5); assert(x.now()<deadline) until w.state=='idle'
  assert(b:execute(w,{code='return 1'}))
 end
 await(b,w)
 assert(not w.result,'partial bytes became consumable result')
 print('PASS real_fault_'..point..'_owned_confirmed_reap_no_partial_result')
end
