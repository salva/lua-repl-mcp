-- Default maximum escaped result through real worker, manager and client pipe.
local x=require('lua_repl_mcp.worker_posix')
local manager=require('lua_repl_mcp.manager')
local transport=require('lua_repl_mcp.client_transport')
local c=require('lua_repl_mcp.codec')
local m=manager.new{}
local rd,wr=assert(x.u.pipe()); x.nonblock(rd); x.nonblock(wr)
x.s.signal(x.s.SIGPIPE,x.s.SIG_IGN)
local t=transport.new(m,{read=function() return nil,'again' end,
 write=function(s)
  local n,msg,e=x.u.write(wr,s)
  if not n and x.retryable(e) then return nil,'again' end
  return n,msg
 end})
local function collect(id)
 local parts={}; local newline=false; local deadline=x.now()+90
 repeat
  assert(t:step(function() end)); assert(x.now()<deadline,'large response watchdog')
  while true do
   local s,_,e=x.u.read(rd,65536)
   if not s then assert(x.retryable(e)); break end
   assert(s~=''); parts[#parts+1]=s
   if s:sub(-1)=='\n' then newline=true end
  end
 until newline
 local text=table.concat(parts)
 assert(text:sub(-1)=='\n' and not text:sub(1,-2):find('\n',1,true))
 local r=assert(c.decode(text,{max_bytes=64*1048576+1,max_depth=160}))
 assert(r.id==id)
 return r.result.structuredContent,r.result.content[1].text,#text
end
local function create(id)
 t:submit(id,'session_create',{})
 return collect(id).session_id
end
local a=create('a'); local b=create('b')
t:submit('maximum','session_execute',{session_id=a,
 code='return string.rep(string.char(34),8388606)',wait_timeout_ms=require('lua_repl_mcp').null})
local v,text,n=collect('maximum')
assert(v.status=='completed' and #v.values[1]==8388606)
assert(#assert(c.encode(v.values,{max_bytes=16*1048576}))==16*1048576)
local duplicate=assert(c.decode(text,{max_bytes=20*1048576,max_depth=160}))
assert(duplicate.values[1]==v.values[1])
-- Unrelated session stays live and usable after maximum response transport.
t:submit('other','session_execute',{session_id=b,code='return 42',wait_timeout_ms=require('lua_repl_mcp').null})
assert(collect('other').values[1]==42)
for _,depth in ipairs({127,128,129}) do
 t:submit('depth'..depth,'session_execute',{session_id=b,
  code='local v=0; for i=1,'..depth..' do v={v} end; return v',
  wait_timeout_ms=require('lua_repl_mcp').null})
 local result=collect('depth'..depth)
 if depth<=128 then
  assert(result.status=='completed'); local v=result.values[1]
  for _=1,depth do v=v[1] end; assert(v==0)
 else assert(result.error.code=='result_serialization_error' and not result.values) end
end
assert(not t.closed)
print('MEASURE worker_buffer_high_water='..m.backend.buffer_high_water..
 ' worker_bound=67108864 command_high_water='..m.backend.pending_high_water)
print('MEASURE default_quote_values=16777216 response_with_newline='..n..
 ' output_high_water='..t.high_water..' bound='..t.output_bytes)
t:close('complete'); x.u.close(rd); x.u.close(wr)
assert(next(m.backend.workers)==nil)
print('PASS legal_maximum_quote_real_worker_fragmented_pipe_duplicate_equality_unrelated_session')
