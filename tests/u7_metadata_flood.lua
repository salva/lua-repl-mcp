-- Corrupt worker notices cannot defeat private-frame and session inventory bounds.
local S=require('lua_repl_mcp.worker_supervisor')
local p=require('lua_repl_mcp.worker_protocol')
local s=S.new{}
local w={state='starting',allocation_generation=1,created_paths={}}
local aborted
s.abort=function(_,worker,reason) aborted=reason; worker.state='terminating' end
for i=1,3 do s:receive(w,p.record('file_created',1,{path='/tmp/path-'..i})) end
assert(#w.created_paths==2 and aborted=='handshake_failed')
s:receive(w,p.record('file_created',1,{path='/tmp/path-4'}))
assert(#w.created_paths==2)
print('PASS corrupt_worker_metadata_notices_bounded_to_two')
