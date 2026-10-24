-- Fault injection at each parent acquisition/setup boundary. Real FDs, fake
-- child ownership (no invented PID is ever passed to the operating system).
local x=require('lua_repl_mcp.worker_posix')
local S=require('lua_repl_mcp.worker_supervisor')
local pipe,clo,fork,nb,kill,wait=x.u.pipe,x.clo,x.u.fork,x.nonblock,x.s.kill,x.w.wait
local function count()
 local n=0
 for _ in require('posix.dirent').files('/proc/self/fd') do n=n+1 end
 return n
end
local socket=require('posix.sys.socket')
local native_pair=socket.socketpair
for _,point in ipairs{'pair','clo1','clo2','fork','nb1'} do
 local before=count(); local calls={}; local sent=0
 local b=S.new{}
 local function hit(kind)
  calls[kind]=(calls[kind] or 0)+1
  if point==kind..calls[kind] or point==kind then error('injected '..point) end
 end
 socket.socketpair=function(...) hit('pair'); return native_pair(...) end
 x.clo=function(...) hit('clo'); return clo(...) end
 x.u.fork=function() hit('fork'); return 123456 end
 x.nonblock=function(...) hit('nb'); return nb(...) end
 x.s.kill=function(pid) assert(pid==123456); sent=sent+1; return 0 end
 x.w.wait=function(pid) assert(pid==123456); return pid,'exited',0 end
 local ok,err=pcall(function()
  local w=b:allocate{}
  assert(w.failure=='spawn_failed' and w.startup_message:find('injected',1,true))
  if point:match('nb') then
   assert(w.pid==123456 and w.state=='terminating' and sent==1)
   b:step(0); assert(w.reaped and w.process_exit_confirmed)
  else assert(w.state=='dead' and not w.pid and sent==0) end
 end)
 socket.socketpair=native_pair
 x.u.pipe=pipe; x.clo=clo; x.u.fork=fork; x.nonblock=nb; x.s.kill=kill; x.w.wait=wait
 assert(ok,err); assert(count()==before,'descriptor leak at '..point)
 print('PASS partial_native_'..point..'_no_fd_leak_child_owned')
end
local G=require('lua_repl_mcp.guardian')
local sock=require('posix.sys.socket'); local pair=sock.socketpair
for _,point in ipairs{'pipe','pair','clo1','clo2','clo3','clo4','clo5','nb1','nb2','fork'} do
 local before=count(); local calls={}; local forked=false
 local function hit(kind)
  calls[kind]=(calls[kind] or 0)+1
  if point==kind or point==kind..calls[kind] then error('injected '..point) end
 end
 x.u.pipe=function() hit('pipe'); return pipe() end
 sock.socketpair=function(...) hit('pair'); return pair(...) end
 x.clo=function(...) hit('clo'); return clo(...) end
 x.nonblock=function(...) hit('nb'); return nb(...) end
 x.u.fork=function() hit('fork'); forked=true; error('unexpected fork') end
 local ok,err=pcall(G.new,{})
 x.u.pipe=pipe; sock.socketpair=pair; x.clo=clo; x.nonblock=nb; x.u.fork=fork
 assert(not ok and tostring(err):find('injected',1,true),tostring(err))
 assert(not forked and count()==before,'guardian partial acquisition leak '..point)
 print('PASS partial_guardian_'..point..'_no_fd_leak_no_child')
end
