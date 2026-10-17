local codec=require('lua_repl_mcp.codec')
local protocol=require('lua_repl_mcp.protocol')
local transport=require('lua_repl_mcp.client_transport')
local steps,closed=0,0
local m={requests={}}
function m:step() steps=steps+1 end
function m:disconnect() closed=closed+1 end
function m:accept(tool,args,id)
 local r={response=args,request_id=id}; self.requests[id]=r; return r
end
function m:preview(r) if not r.done then return r.response end end
function m:release() end
function m:commit(r,send)
 if send(r.response) then r.done=true; self.requests[r.request_id]=nil end
end
local emitted=''
local reads=0
local t=transport.new(m,{read=function() reads=reads+1; return nil,'again' end,
 write=function(s) local n=math.min(7,#s); emitted=emitted..s:sub(1,n); return n end})
t:submit('id','test',{status='completed',values=codec.array({'quote" slash\\ control\0'})})
assert(t:step(function() end)); assert(#t.pending==0 and t.bytes==0)
local wire=assert(codec.decode(emitted))
assert(wire.id=='id' and wire.result.structuredContent.values[1]=='quote" slash\\ control\0')
assert(codec.decode(wire.result.content[1].text).values[1]==wire.result.structuredContent.values[1])
assert(steps==1 and reads==1)
local text,original=protocol.encode_result('id',{values=codec.array({string.rep('x',2000)})},
 {max_bytes=1024,max_depth=160})
assert(text and not original)
assert(codec.decode(text).result.structuredContent.error.code=='limit_exceeded')
local stopped=transport.new(m,{read=function() return nil,'again' end,write=function() return nil,'again' end},
 {response_bytes=1024,output_bytes=2048})
assert(stopped:enqueue(string.rep('x',1023)))
assert(stopped:enqueue(string.rep('x',1023)))
assert(stopped.high_water==2048)
assert(not stopped:enqueue('x') and closed==1)
local partial=transport.new(m,{read=function() return nil,'again' end,
 write=function() return nil,'broken pipe' end})
partial:submit(1,'test',{status='completed'})
assert(not partial:step(function() end) and closed==2)
print('PASS encoded_equality_short_writes_preflight_stopped_reader_bound_and_failure_cleanup')
print('MEASURE output_high_water='..stopped.high_water..' output_bound=2048')
