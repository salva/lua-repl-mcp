-- A bounded bulk frame must not be recopied in full on every 64KiB turn.
local W=require('lua_repl_mcp.guardian_channel')
local x=require('lua_repl_mcp.worker_posix')
local read=x.u.read
local function measure(bytes)
 local block=string.rep(' ',65536)
 local ch={fd=-1,limit=bytes,input=''}
 x.u.read=function() return block end
 collectgarbage('collect'); collectgarbage('stop')
 local before=collectgarbage('count')
 for i=1,bytes//65536 do W.receive(ch,function() error('incomplete frame applied') end) end
 local allocation=collectgarbage('count')-before
 collectgarbage('restart'); x.u.read=read
 print(('OBS guardian_incomplete_frame bytes=%d allocation_KiB=%.3f'):format(bytes,allocation))
 return allocation
end
local small=measure(1048576)
local large=measure(16777216)
assert(large<small*24,'bulk accumulation repeatedly copies retained prefix')
-- Full record applies only at newline, exactly once, and oversize is rejected.
local chunks={'{"items":', '[],"done":true}', '\n'}
local index=0
x.u.read=function() index=index+1; if index%2==0 then return nil,'again',x.e.EAGAIN end; return chunks[(index+1)//2] end
local ch={fd=-1,limit=128,input=''}; local applied=0
for i=1,3 do W.receive(ch,function(items,done) assert(#items==0 and done); applied=applied+1 end) end
assert(applied==1 and ch.input_bytes==0 and #ch.input_parts==0)
x.u.read=function() return string.rep('x',129) end
assert(not pcall(W.receive,{fd=-1,limit=128,input=''},function() error('oversize applied') end))
x.u.read=read
print('PASS guardian_linear_bulk_accumulation_and_complete_frame_bounds')
