-- A structurally incomplete worker error must not become a public result.
local c=require('lua_repl_mcp.codec')
local p=require('lua_repl_mcp.worker_protocol')
local raw=assert(c.encode({protocol_version=1,type='result',allocation_generation=1,
 execution_generation=1,result={status='failed',error={}}}))
local decoded=p.decode(raw)
print('MEASURE malformed_empty_error_accepted='..tostring(decoded~=nil))
assert(decoded==nil,'malformed worker error accepted as a valid execution result')
