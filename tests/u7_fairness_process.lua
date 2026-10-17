-- Real owned workers + real nonblocking client pipes, admission-saturated waits.
local x=require('lua_repl_mcp.worker_posix')
local manager=require('lua_repl_mcp.manager')
local transport=require('lua_repl_mcp.client_transport')
local c=require('lua_repl_mcp.codec')
local null=require('lua_repl_mcp').null
x.s.signal(x.s.SIGPIPE,x.s.SIG_IGN)
local function run()
 local ir,iw=assert(x.u.pipe()); local or_,ow=assert(x.u.pipe())
 for _,fd in ipairs({ir,iw,or_,ow}) do x.nonblock(fd) end
 local m=manager.new{}
 local t=transport.new(m,{read=function(n)
  local s,msg,e=x.u.read(ir,n); if not s and x.retryable(e) then return nil,'again' end
  if s=='' then return nil,'eof' end; return s,msg
 end,write=function(s)
  local n,msg,e=x.u.write(ow,s); if not n and x.retryable(e) then return nil,'again' end
  return n,msg
 end})
 local replies,tail={},''
 local function drain()
  while true do
   local s,_,e=x.u.read(or_,65536)
   if not s then assert(x.retryable(e)); break end
   assert(#s>0); tail=tail..s
  end
  while true do
   local p=tail:find('\n',1,true); if not p then break end
   local r=assert(c.decode(tail:sub(1,p-1))); replies[r.id]=r
   tail=tail:sub(p+1)
  end
 end
 local function route(frame)
  local r=assert(c.decode(frame))
  if r.method=='notifications/cancelled' then t:cancel(r.params.requestId)
  elseif r.method=='ping' then
   assert(t:enqueue(assert(c.encode({jsonrpc='2.0',id=r.id,result=c.object({})}))))
  else t:submit(r.id,r.params.name,r.params.arguments) end
 end
 local function tick() assert(t:step(route)); drain() end
 local function until_(test)
  local deadline=x.now()+8
  while not test() do assert(x.now()<deadline,'fairness watchdog'); tick() end
 end
 local function send(id,tool,args)
  local frame=assert(c.encode({jsonrpc='2.0',id=id,method='tools/call',
   params={name=tool,arguments=args or c.object({})}}))..'\n'
  assert(x.u.write(iw,frame)==#frame)
 end
 send('a','session_create'); send('b','session_create'); send('d','session_create')
 until_(function() return replies.a and replies.b and replies.d end)
 local a=replies.a.result.structuredContent.session_id
 local b=replies.b.result.structuredContent.session_id
 local d=replies.d.result.structuredContent.session_id
 send('run-a','session_execute',{session_id=a,code='while true do end',wait_timeout_ms=0})
 send('run-b','session_execute',{session_id=b,code='while true do end',wait_timeout_ms=0})
 until_(function() return replies['run-a'] and replies['run-b'] end)
 -- Submit through real fragmented client reads (pipe is nonblocking); each tick
 -- admits at most 16 frames and still services owned worker timers.
 for i=1,256 do
  send('wait'..i,'session_wait',{session_id=i%2==0 and a or b,wait_timeout_ms=null})
  tick()
 end
 assert(m.slots.ordinary==256 and #t.pending==256)
 send('excess','session_wait',{session_id=a,wait_timeout_ms=null})
 send('list','session_list')
 assert(x.u.write(iw,'{"jsonrpc":"2.0","id":"ping","method":"ping"}\n'))
 assert(x.u.write(iw,'{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":"wait1"}}\n'))
 send('kill','session_kill',{session_id=a})
 until_(function() return replies.excess and replies.list and replies.ping and replies.kill end)
 assert(replies.excess.result.structuredContent.error.code=='limit_exceeded')
 assert(replies.kill.result.structuredContent.process_exit_confirmed)
 until_(function() return not m.sessions[b] and not m.sessions[a] end)
 assert(not replies.wait1,'cancelled request must not reply')
 -- General controls saturated before a tick must leave exactly eight kills.
 for i=1,24 do t:submit('cl'..i,'session_list',{}) end
 for i=1,8 do t:submit('ck'..i,'session_kill',{session_id=d}) end
 assert(m.slots.control==24 and m.slots.kill==8)
 t:submit('cl-excess','session_list',{})
 assert(#t.pending==32)
 until_(function() return replies.ck8 and replies['cl-excess'] end)
 assert(replies['cl-excess'].result.structuredContent.error.code=='limit_exceeded')
 -- Sustained actual ping traffic cannot starve a worker hard deadline.
 send('timed','session_execute',{code='while true do end',execution_timeout_ms=30,wait_timeout_ms=null})
 local deadline=x.now()+5; local i=0
 repeat
  i=i+1
  assert(x.u.write(iw,'{"jsonrpc":"2.0","id":"flood'..i..'","method":"ping"}\n'))
  tick(); assert(x.now()<deadline)
 until replies.timed
 assert(replies.timed.result.structuredContent.error.code=='execution_timeout')
 assert(t.high_water<=t.output_bytes and t.input_high_water<=t.input.limit+65536)
 print('MEASURE saturated_output_high_water='..t.high_water..' bound='..t.output_bytes..
  ' input_high_water='..t.input_high_water..' ping_ticks_before_timeout='..i)
 t:close('test complete')
 for _,fd in ipairs({ir,iw,or_,ow}) do x.u.close(fd) end
 assert(next(m.sessions)==nil and next(m.backend.workers)==nil)
end
run()
print('PASS real_pipe_256_waits_reject_list_ping_cancel_kill_reserved_controls_and_timer_flood')
