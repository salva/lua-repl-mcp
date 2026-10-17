-- Reap is exit evidence, not permission to discard unread final records.
local S=require('lua_repl_mcp.worker_supervisor')
local p=require('lua_repl_mcp.worker_protocol')
local x=require('lua_repl_mcp.worker_posix')
local read,poll,wait=x.u.read,x.p.poll,x.w.wait
x.p.poll=function() end
x.w.wait=function() return 12345,'exited',0 end
local ok,err=pcall(function()
 for _,fragment in ipairs{17,65536} do
  local s=S.new{clock=function() return 0 end}
  local wire=assert(p.encode(p.record('file_created',1,{path='/stdout'}),s.limits))..assert(p.encode(p.record('startup_error',1,{reason='stdio_setup_failed',message='final-error'}),s.limits))
  local pos,calls=1,0
  x.u.read=function(_,n)
   calls=calls+1; if calls%2==0 then return nil,'again',x.e.EAGAIN end
   if pos>#wire then return '' end
   local text=wire:sub(pos,pos+math.min(n,fragment)-1); pos=pos+#text; return text
  end
  local w={state='starting',allocation_generation=1,execution_generation=0,deadline=30,pid=12345,read_fd=101,buffer='',pending='',created_paths={}}
  s.workers={w}
  local turns=0
  repeat s:step(0); turns=turns+1; assert(turns<30) until w.state=='dead'
  assert(w.reaped and w.process_exit_confirmed)
  assert(w.created_paths[1]=='/stdout','reaped startup path lost')
  assert(w.failure=='stdio_setup_failed' and w.startup_message=='final-error','final startup record lost at reap: '..tostring(w.failure))
 end
 local s=S.new{clock=function() return 0 end}
 local w={state='starting',allocation_generation=1,execution_generation=0,deadline=30,pid=12345,read_fd=101,buffer='',pending='',created_paths={}}
 s.workers={w}; local first=true
 x.u.read=function() if first then first=false; return '{"type":' end; return '' end
 s:step(0)
 assert(w.state=='dead' and w.failure=='handshake_failed' and w.process_exit_confirmed)
 print('PASS reaped_startup_multi_record_tail_fragmented_error_and_truncated_eof')
end)
x.u.read=read; x.p.poll=poll; x.w.wait=wait
assert(ok,err)
