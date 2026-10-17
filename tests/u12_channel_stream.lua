-- Exact streaming/backpressure/order test; no native child or PID is used.
local wire=require('lua_repl_mcp.guardian_channel')
local x=require('lua_repl_mcp.worker_posix')
local codec=require('lua_repl_mcp.codec')
local write,read=x.u.write,x.u.read
local ch={fd=123,limit=2048,output='',offset=1}
local rx={fd=124,limit=2048,input=''}
local bytes=''; local received={}; local done_count=0; local high=0; local blocked=true
x.u.write=function(_,s)
 if blocked then return nil,'again',x.e.EAGAIN end
 local n=math.min(113,#s); bytes=bytes..s:sub(1,n); return n
end
x.u.read=function()
 if bytes=='' then return nil,'again',x.e.EAGAIN end
 local s=bytes:sub(1,79); bytes=bytes:sub(#s+1); return s
end
local function accept(items,done)
 for _,v in ipairs(items) do received[#received+1]=v end
 if done then done_count=done_count+1 end
end
local ok,err=pcall(function()
 local batch={}
 for i=1,30 do batch[i]={id=i,payload=string.rep('x',1000)} end
 wire.enqueue(ch,batch)
 assert(wire.busy(ch) and #ch.output<ch.limit)
 assert(not pcall(wire.enqueue,ch,{}),'must reject concurrent logical batches')
 wire.flush(ch); assert(ch.offset==1,'EAGAIN must not consume output')
 blocked=false
 local turns=0
 repeat
  wire.flush(ch); wire.receive(rx,accept)
  high=math.max(high,#ch.output)
  turns=turns+1; assert(turns<1000,'stream watchdog')
 until not wire.busy(ch) and bytes==''
 assert(#received==30 and done_count==1)
 for i,v in ipairs(received) do assert(v.id==i and v.payload==batch[i].payload) end
 assert(high<=ch.limit+1,'encoded aggregate was retained')
 wire.enqueue(ch,{})
 repeat wire.flush(ch); wire.receive(rx,accept) until not wire.busy(ch) and bytes==''
 assert(done_count==2 and #received==30,'empty batch completion missing')
 local oversized={fd=125,limit=64,output='',offset=1}
 assert(not pcall(wire.enqueue,oversized,{{payload=string.rep('x',100)}}),'single oversized item must still fail')
 print('PASS guardian_stream_order_partial_write_EAGAIN_one_completion_empty_bound_single_overflow')
end)
x.u.write=write; x.u.read=read
assert(ok,err)
