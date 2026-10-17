-- Real POSIX pipe short writes/EAGAIN and disconnect against owned workers.
local x=require('lua_repl_mcp.worker_posix')
local manager=require('lua_repl_mcp.manager')
local transport=require('lua_repl_mcp.client_transport')
x.s.signal(x.s.SIGPIPE,x.s.SIG_IGN)
local function run(phase)
 local rd,wr=assert(x.u.pipe()); x.nonblock(rd); x.nonblock(wr)
 local m=manager.new{}
 local t=transport.new(m,{read=function() return nil,'again' end,
  write=function(s)
   local n,msg,errno=x.u.write(wr,s)
   if not n and x.retryable(errno) then return nil,'again' end
   return n,msg
  end})
 local cr=m:accept('session_create',{},'create')
 local deadline=x.now()+5
 while phase~='startup' and not m:preview(cr) do
  assert(x.now()<deadline); m:step(10)
 end
 if phase=='execution' then
  assert(m:commit(cr,function() return true end))
  local r=m:accept('session_execute',{session_id=cr.session.id,code='while true do end'},'exec')
  assert(r.session.worker.state=='running')
 end
 -- Fill a real pipe with a complete queued frame; reader deliberately stopped.
 assert(t:enqueue(string.rep('x',200000)))
 assert(t:step(function() end))
 assert(t.queue[1] and t.queue[1].offset>1 and t.queue[1].offset<#t.queue[1].text)
 assert(t.bytes==200001,'accounting must include retained written prefix')
 print('MEASURE '..phase..' retained='..t.bytes..' bound='..t.output_bytes..
  ' actual_short_progress='..(t.queue[1].offset-1))
 assert(x.u.close(rd)); assert(not t:step(function() end))
 assert(t.closed and m.closed)
 assert(#m.backend.workers==0 or next(m.backend.workers)==nil)
 assert(next(m.sessions)==nil)
 x.u.close(wr)
end
for _,phase in ipairs({'startup','execution','transmission'}) do run(phase) end
print('PASS real_stopped_pipe_short_output_epipe_owned_worker_cleanup')
