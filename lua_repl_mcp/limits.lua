-- Validated evaluator, admission and connection-wide encoding budgets.
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
-- Admission bounds are validated before constructing a backend or allocating.
function M.admission(options)
  local result={sessions=64,ordinary=256,control=32,kill_reserve=8}
  for k,v in pairs(options or {}) do
    assert(result[k]~=nil,'unknown admission limit')
    assert(math.type(v)=='integer' and v>0,'admission limits must be positive integers')
    result[k]=v
  end
  assert(result.kill_reserve>=8 and result.control>=result.kill_reserve,
    'control capacity must include at least eight kill-only slots')
  return result
end
-- A configured budget is shared by the manager, exec worker and transport.
-- Defaults remain normative, including their separately documented fit conflict.
function M.authored(r)
 local v={}
 for _,k in ipairs({'input_bytes','values_bytes','diagnostic_bytes','max_depth',
  'worker_bytes','response_bytes','output_bytes'}) do v[k]=r[k] end
 return v
end
function M.connection(options)
 local r={input_bytes=16*1048576,values_bytes=16*1048576,diagnostic_bytes=65536,
  max_depth=128,worker_bytes=20*1048576,response_bytes=64*1048576,output_bytes=128*1048576}
 assert(options==nil or type(options)=='table','limits must be a table')
 for k,v in pairs(options or {}) do
  assert(r[k]~=nil,'unknown connection limit')
  assert(math.type(v)=='integer' and v>0 and v<=2147483647,'invalid connection limit')
  r[k]=v
 end
 M.evaluator{max_bytes=r.values_bytes,max_depth=r.max_depth,diagnostic_bytes=r.diagnostic_bytes}
 assert(r.max_depth<=512,'configured depth exceeds supported encoder depth')
 -- 64 KiB headroom bounds fixed envelopes, generation numbers and notices.
 -- Diagnostic UTF-8 text costs at most 6x in JSON; public text duplication
 -- costs at most 3x encoded payload. Encoded JSON re-escape costs <=2x.
 r.worker_required=math.max(r.input_bytes,r.values_bytes,6*r.diagnostic_bytes)+65536
 r.response_required=r.input_bytes+3*math.max(r.values_bytes,6*r.diagnostic_bytes)+65536
 assert(r.worker_bytes>=r.worker_required,'worker budget cannot hold configured payload')
 assert(r.output_bytes>=r.response_bytes+1,'output must hold response plus newline')
 local defaults=r.input_bytes==16*1048576 and r.values_bytes==16*1048576 and
  r.diagnostic_bytes==65536 and r.max_depth==128 and r.worker_bytes==20*1048576 and
  r.response_bytes==64*1048576 and r.output_bytes==128*1048576
 if not defaults then
  assert(r.response_bytes>=r.response_required,'response budget cannot hold configured payload and ID')
 end
 r.default_fit_unresolved=defaults
 return r
end
return M
