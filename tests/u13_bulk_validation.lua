-- Complete bulk bytes are not equivalent to a validated/applied fragment.
local W=require('lua_repl_mcp.guardian_channel')
local x=require('lua_repl_mcp.worker_posix')
local c=require('lua_repl_mcp.codec')
local text=assert(c.encode({items={{payload=string.rep('a',262144)}},done=true}))..'\n'
local read=x.u.read; local pos=1
x.u.read=function(_,n)
 if pos>#text then return nil,'again',x.e.EAGAIN end
 local v=text:sub(pos,pos+n-1); pos=pos+#v; return v
end
local ch={fd=-1,limit=#text,input=''}; local applied=0
local function accept(items) assert(#items[1].payload==262144); applied=applied+1 end
while pos<=#text do W.receive(ch,accept) end
assert(applied==0,'full frame synchronously validated/applied before next control turn')
local turns=0
while applied==0 do turns=turns+1; assert(turns<30); W.receive(ch,accept) end
assert(applied==1 and turns>1)
x.u.read=read
-- Same strict parser branches/errors with and without native suspension.
for _,source in ipairs{'false','null','[1e-7,0,-2]','{"x":"\\ud83d\\ude00"}','[1,]','{"x":1,"x":2}','"\\ud800"','1e999','[[]]'} do
 local a,e=c.decode(source,{max_depth=1})
 local co=coroutine.create(function() return c.decode(source,{max_depth=1,checkpoint=coroutine.yield}) end)
 local ok,b,f=coroutine.resume(co); assert(ok)
 while coroutine.status(co)~='dead' do ok,b,f=coroutine.resume(co); assert(ok) end
 assert((e==nil)==(f==nil))
 if e then assert(e.reason==f.reason and e.path==f.path) else assert(c.encode(a)==c.encode(b)) end
end
print('PASS bulk_full_frame_validation_yields_before_application turns='..turns)
