-- Approved SPEC14.4 correction: check actual production configuration without
-- overriding its capacities. No worker/backend allocation is needed to validate.
local limits=require('lua_repl_mcp.limits')
local r=limits.connection()
local H=1048576
local B=r.input_bytes+r.values_bytes+6*r.diagnostic_bytes+H
local required_response=r.input_bytes+3*B+H
local gaps=0
local function check(ok,label)
 print((ok and 'PASS ' or 'FAIL ')..label)
 if not ok then gaps=gaps+1 end
end
print(('MEASURE worker=%d response=%d output=%d B=%d response_floor=%d'):format(
 r.worker_bytes,r.response_bytes,r.output_bytes,B,required_response))
check(r.input_bytes==16*H and r.values_bytes==16*H,'input_values_unchanged')
check(r.worker_bytes==64*H,'production_worker_default_64MiB')
check(r.response_bytes==128*H,'production_response_default_128MiB')
check(r.output_bytes==256*H,'production_output_default_256MiB')
check(r.default_fit_unresolved==nil,'no_unresolved_default_flag')
check(r.worker_required==B and r.response_required==required_response,'uniform_SPEC_floors')
-- Small configurations isolate each floor, including explicit default operands.
local function config(w,response,out)
 return {worker_bytes=w,response_bytes=response,output_bytes=out}
end
check(not pcall(limits.connection,config(B-1,required_response,required_response+1)),
 'worker_floor_minus_one_rejected')
check(pcall(limits.connection,config(B,required_response,required_response+1)),
 'exact_floors_accepted')
check(not pcall(limits.connection,config(B,required_response-1,required_response+1)),
 'response_floor_minus_one_rejected')
check(not pcall(limits.connection,config(B,required_response,required_response)),
 'newline_capacity_rejected')
check(not pcall(limits.connection,{input_bytes=2147483647,values_bytes=2147483647,
 diagnostic_bytes=2147483647,worker_bytes=2147483647,response_bytes=2147483647,
 output_bytes=2147483647}),'unrepresentable_coupled_capacity_rejected')
assert(gaps==0,'approved SPEC14.4 production budget gaps='..gaps)
