-- Exact encoded/public-output boundaries and manager-copy budgets.
local c=require('lua_repl_mcp.codec')
local p=require('lua_repl_mcp.protocol')
local f=require('lua_repl_mcp.framing')
local transport=require('lua_repl_mcp.client_transport')
local payload={status='completed',values=c.array({'escaped"\\\0'})}
local full=assert(p.encode_result('id',payload))
for _,delta in ipairs({-1,0,1}) do
 local encoded,original=p.encode_result('id',payload,{max_bytes=#full+delta,max_depth=160})
 assert(original==(delta>=0))
 if delta>=0 then assert(encoded==full) end
end
for _,delta in ipairs({-1,0,1}) do
 local frame=f.new(64); local ok=frame:feed(string.rep('x',64+delta)..'\n')
 local value,err=frame:pop()
 assert((ok==true)==(delta<=0))
 assert((value~=nil)==(delta<=0))
 assert((err~=nil)==(delta>0))
 assert(#frame.buffer<=65)
end
for _,n in ipairs({2047,2048,2049}) do
 local m={disconnect=function(self) self.closed=true end}
 local t=transport.new(m,{}, {response_bytes=1024,output_bytes=2048})
 local ok=t:enqueue(string.rep('x',n-1))
 assert(ok==(n<=2048))
 assert(t.high_water<=2048)
 assert((not not m.closed)==(n>2048))
end
-- clone default still uses input limits; callers may explicitly select a result
-- budget and depth without contaminating public input validation.
local value={}; local v=value
for _=1,128 do v.child={}; v=v.child end
assert(not c.clone(value))
assert(c.clone(value,{max_bytes=1024*1024,max_depth=160}))
print('PASS exact_response_input_frame_output_and_explicit_clone_depth_boundaries')
