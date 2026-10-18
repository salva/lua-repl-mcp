-- Native turn work is shared, not one maximal frame allowance per worker.
local S=require('lua_repl_mcp.worker_supervisor')
local x=require('lua_repl_mcp.worker_posix')
local s=S.new{}; s.limits.worker_bytes=131072 -- small framing seam isolates turn arithmetic
local read,poll=x.u.read,x.p.poll
local count=0
x.u.read=function() count=count+65536; return string.rep(' ',65536) end
x.p.poll=function() end
for i=1,8 do s.workers[i]={state='idle',read_fd=100+i,buffer='',pending='',created_paths={}} end
local ok,err=pcall(function()
 s:step(0)
 assert(count<=65536,'aggregate turn reads '..count..' bytes; expected shared ingress unit')
 local first=s.workers[1].buffer_bytes
 s:step(0)
 assert(s.workers[1].buffer_bytes==first,'round robin must advance past previous ingress owner')
 assert((s.workers[2].buffer_bytes or 0)>0,'second admitted worker must progress')
end)
x.u.read=read; x.p.poll=poll
assert(ok,err)
print('PASS aggregate_native_ingress_unit_and_rotating_owner')
