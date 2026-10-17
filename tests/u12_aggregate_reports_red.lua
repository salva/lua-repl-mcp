-- U12 aggregate-report boundary regression. No child processes are needed:
-- exercise the exact channel enqueue primitive used by guardian report batches.
local limits=require('lua_repl_mcp.limits')
local codec=require('lua_repl_mcp.codec')
local wire=require('lua_repl_mcp.guardian_channel')
local values_bytes=1048576
local configured=limits.connection{
 input_bytes=1024,values_bytes=values_bytes,diagnostic_bytes=128,
 worker_bytes=3*1048576,response_bytes=8*1048576,output_bytes=9*1048576,
}
local admission=limits.admission()
local payload=string.rep('x',values_bytes-4) -- ["..."] is exactly V bytes
local values=codec.array{payload}
assert(#assert(codec.encode(values))==values_bytes)
local reports={}
for id=1,9 do
 local result={status='completed',values=values}
 local report={id=id,state='idle',execution_generation=1,result=result}
 -- Every allocation's maximal result fits the configured single-report bound.
 assert(codec.encode({report},{max_bytes=configured.response_bytes,max_depth=160}))
 reports[#reports+1]=report
end
assert(#reports<=admission.sessions,'fixture must remain within session admission')
local ch={limit=configured.response_bytes,output='',offset=1}
local ok,err=pcall(wire.enqueue,ch,reports)
print('OBSERVE legal_allocations='..#reports..' values_bytes='..values_bytes..
 ' report_bound='..ch.limit..' enqueue_ok='..tostring(ok)..' error='..tostring(err))
assert(ok,'U12: multiple legal maximal results rejected by bounded aggregate guardian report')
print('PASS multiple_legal_maximal_results')
