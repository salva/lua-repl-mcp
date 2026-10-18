local S=require('lua_repl_mcp.worker_supervisor')
local x=require('lua_repl_mcp.worker_posix')
local read=x.u.read
local function measure(n)
 local s=S.new{clock=function() return 0 end}
 local w={state='running',read_fd=101,buffer=''}
 local block=string.rep(' ',65536)
 x.u.read=function() return block end
 collectgarbage('collect'); collectgarbage('stop')
 local start=collectgarbage('count')
 for i=1,n//65536 do s.turn_read_remaining=65536; s:drain(w) end
 local amount=collectgarbage('count')-start; collectgarbage('restart')
 x.u.read=read
 assert(not w.validation and not w.result and w.state=='running')
 print(('OBS native_incomplete bytes=%d allocation_KiB=%.3f'):format(n,amount))
 return amount
end
local a=measure(1048576); local b=measure(16777216)
assert(b<a*24,'native accumulation recopies whole prefix')
print('PASS native_incomplete_frame_allocation')
-- Oversize is checked before retention; active abort frees partial ownership.
local close=x.u.close; x.u.close=function() return 0 end
local s=S.new{clock=function() return 0 end}; s.limits.worker_bytes=4
local w={state='running',read_fd=101,buffer=''}
x.u.read=function() return '1234' end
s.turn_read_remaining=4; s:drain(w)
assert(w.buffer_bytes==4 and not w.validation)
x.u.read=function() return '5' end
s.turn_read_remaining=1; s:drain(w)
assert(w.failure=='corrupt_worker' and not w.read_fd and not w.buffer_parts and w.buffer_bytes==0)
w={state='running',read_fd=101,buffer=''}
x.u.read=function() return '123' end
s.turn_read_remaining=3; s:drain(w); s:abort(w,'request_cancelled',0)
assert(w.failure=='request_cancelled' and not w.buffer_parts and w.buffer_bytes==0 and w.cleanup_deadline==30)
x.u.read=read; x.u.close=close
print('PASS native_partial_overflow_abort_releases_ownership_original_disposal')
