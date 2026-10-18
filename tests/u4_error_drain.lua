-- Feed an invalid raw worker reply through the real nonblocking drain path.
local S=require('lua_repl_mcp.worker_supervisor')
local x=require('lua_repl_mcp.worker_posix')
local c=require('lua_repl_mcp.codec')
local b=S.new{}
local read,write=assert(x.u.pipe()); x.nonblock(read)
local w={state='running',allocation_generation=1,execution_generation=1,
 read_fd=read,buffer='',pending=''}
local raw=assert(c.encode({protocol_version=1,type='result',allocation_generation=1,
 execution_generation=1,result={status='failed',error={}}}))..'\n'
assert(x.u.write(write,raw)==#raw)
b:drain(w)
-- Parsing is resumable; receipt of a complete frame is not validation.
local turns=0
while w.validation do
 turns=turns+1; assert(turns<100,'invalid reply validation watchdog')
 b:drain(w)
end
x.u.close(write)
assert(w.state=='terminating' and w.failure=='corrupt_worker')
assert(w.result==nil and w.read_fd==nil and w.buffer=='')
print('PASS malformed_nested_error_disposes_worker_without_completion')
