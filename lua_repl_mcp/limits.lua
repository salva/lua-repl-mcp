-- U1 evaluator limits only. Transport/manager coupling belongs to U7.
local M={}
local minimum_diagnostics=#require('lua_repl_mcp.errors').notice
function M.evaluator(options)
  options=options or {}
  assert(type(options)=='table','options must be a table')
  local result={max_bytes=16*1024*1024,max_depth=128,diagnostic_bytes=65536}
  for k,v in next,options do
    assert(result[k]~=nil,'unknown evaluator limit')
    assert(math.type(v)=='integer' and v>0,'limits must be positive integers')
    result[k]=v
  end
  assert(result.diagnostic_bytes>=minimum_diagnostics,'diagnostic limit cannot hold loss notice')
  return result
end
return M
