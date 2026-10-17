-- Invalid coupled limits must fail before any backend construction/allocation.
local manager=require('lua_repl_mcp.manager')
local saved=package.loaded['lua_repl_mcp.worker_supervisor']
local calls=0
package.loaded['lua_repl_mcp.worker_supervisor']={new=function() calls=calls+1; error('backend constructed') end}
for _,limits in ipairs({{worker_bytes=1},{response_bytes=1},{output_bytes=1},
 {input_bytes=2147483647},{diagnostic_bytes=2147483647},
 {values_bytes=2147483647},{response_bytes=2147483647,output_bytes=2147483647}}) do
 local ok=pcall(manager.new,{limits=limits})
 assert(not ok and calls==0,'invalid capacity reached backend')
end
package.loaded['lua_repl_mcp.worker_supervisor']=saved
print('PASS incompatible_and_overflow_capacities_rejected_before_backend_construction')
