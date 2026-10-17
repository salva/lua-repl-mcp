local W=require('lua_repl_mcp.guardian_channel')
local C=require('lua_repl_mcp.codec')
local x=require('lua_repl_mcp.worker_posix')
local write=x.u.write
local pieces={}
x.u.write=function(_,s) pieces[#pieces+1]=s; return #s end
local ok,err=pcall(function()
 local ch={fd=-1,limit=2*1048576,output='',offset=1}
 local value={payload=string.rep('\0',131072)}
 W.enqueue(ch,{value})
 assert(W.busy(ch) and ch.output=='','bulk enqueue encoded full escaped payload synchronously')
 assert(#pieces==0)
 local turns=0
 while W.busy(ch) do turns=turns+1; assert(turns<100); W.flush(ch) end
 local text=table.concat(pieces)
 local frame=assert(C.decode(text))
 assert(frame.done and frame.items[1].payload==value.payload and turns>2)
 for _,v in ipairs{C.array{1e-7,false,C.object{}}, {s='é😀\0\\"'}, {a=C.array{1,2,3}}} do
  local expected=assert(C.encode(v))
  local co=coroutine.create(function() return C.encode(v,{checkpoint=coroutine.yield}) end)
  local success,result=coroutine.resume(co); assert(success)
  while coroutine.status(co)~='dead' do success,result=coroutine.resume(co); assert(success) end
  assert(result==expected)
 end
 -- Late invalid data/overflow never produces a partial frame.
 for _,value in ipairs{{payload=string.rep('x',131072),z=string.char(255)}, {payload=string.rep('x',131072)}} do
  pieces={}
  local bad={fd=-1,limit=value.z and 1048576 or 1000,output='',offset=1}
  W.enqueue(bad,{value})
  local success=pcall(function() while W.busy(bad) do W.flush(bad) end end)
  assert(not success and #pieces==0)
 end
 -- Whole original JSON data remains lexically identical, not quoted.
 local source='{"extra":1e-7,"s":"x"}'..string.rep(' ',131072)
 local original=assert(C.json_data(source))
 local expected=assert(C.encode({request=original}))
 local co=coroutine.create(function() return C.encode({request=original},{checkpoint=coroutine.yield}) end)
 local success,result=coroutine.resume(co); assert(success)
 while coroutine.status(co)~='dead' do success,result=coroutine.resume(co); assert(success) end
 assert(result==expected and result:find(source,1,true))
 print('PASS cooperative_bulk_encoding_no_partial_write_errors_original turns='..turns)
end)
x.u.write=write; assert(ok,err)
