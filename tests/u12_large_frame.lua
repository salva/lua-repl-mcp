-- Private reports must not inherit the smaller public input decoder default.
local c=require('lua_repl_mcp.codec')
local wire=require('lua_repl_mcp.guardian_channel')
local x=require('lua_repl_mcp.worker_posix')
local size=17*1048576
local frame=assert(c.encode({items={{id=1,payload=string.rep('x',size)}},done=true},{max_bytes=20*1048576}))..'\n'
local rx={fd=123,limit=20*1048576,input=''}
local read=x.u.read; local offset=1; local seen=false
x.u.read=function(_,n)
 if offset>#frame then return nil,'again',x.e.EAGAIN end
 local s=frame:sub(offset,offset+n-1); offset=offset+#s; return s
end
local ok,err=pcall(function()
 repeat wire.receive(rx,function(items,done)
  assert(not seen and done and items[1].id==1 and #items[1].payload==size)
  seen=true
 end) until offset>#frame
 assert(seen,'large legal frame was not delivered')
 print('PASS configured_guardian_report_17MiB_above_public_input_decode_default')
end)
x.u.read=read
assert(ok,err)
