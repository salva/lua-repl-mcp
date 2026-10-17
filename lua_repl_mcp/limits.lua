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
    assert(math.type(v)=='integer' and v>0 and v<=2147483647,'admission limits must be positive integers')
    result[k]=v
  end
  assert(result.kill_reserve>=8 and result.control>=result.kill_reserve,
    'control capacity must include at least eight kill-only slots')
  -- Validate aggregate queue/disposal arithmetic before backend construction.
  -- An allocation owns allocate/execute/close/release, plus abort and ack.
  local ceiling=2147483647
  assert(result.sessions<=ceiling//6,'admission queue capacity overflow')
  assert(result.ordinary<=ceiling-result.control,'admission request capacity overflow')
  assert(result.ordinary+result.control<=ceiling-result.kill_reserve,'admission request capacity overflow')
  return result
end
-- A configured budget is shared by the manager, exec worker and transport.
-- SPEC14.4 floors apply uniformly before backend construction.
function M.authored(r)
 local v={}
 for _,k in ipairs({'input_bytes','values_bytes','diagnostic_bytes','max_depth',
  'worker_bytes','response_bytes','output_bytes'}) do v[k]=r[k] end
 return v
end
function M.connection(options)
 local r={input_bytes=16*1048576,values_bytes=16*1048576,diagnostic_bytes=65536,
  max_depth=128,worker_bytes=64*1048576,response_bytes=128*1048576,output_bytes=256*1048576}
 assert(options==nil or type(options)=='table','limits must be a table')
 for k,v in pairs(options or {}) do
  assert(r[k]~=nil,'unknown connection limit')
  assert(math.type(v)=='integer' and v>0 and v<=2147483647,'invalid connection limit')
  r[k]=v
 end
 M.evaluator{max_bytes=r.values_bytes,max_depth=r.max_depth,diagnostic_bytes=r.diagnostic_bytes}
 assert(r.max_depth<=512,'configured depth exceeds supported encoder depth')
 -- Check every intermediate against the supported capacity ceiling before
 -- multiplying/adding; no wrapped arithmetic or default-only exceptions.
 local ceiling=2147483647
 local function add(a,b)
  assert(a<=ceiling-b,'coupled capacity overflow')
  return a+b
 end
 local function mul(a,b)
  assert(a<=ceiling//b,'coupled capacity overflow')
  return a*b
 end
 local H=1048576
 r.worker_required=add(add(add(r.input_bytes,r.values_bytes),mul(r.diagnostic_bytes,6)),H)
 r.response_required=add(add(r.input_bytes,mul(r.worker_required,3)),H)
 assert(r.worker_bytes>=r.worker_required,'worker budget cannot hold configured payload')
 assert(r.response_bytes>=r.response_required,'response budget cannot hold configured payload and ID')
 assert(r.output_bytes>=add(r.response_bytes,1),'output must hold response plus newline')
 return r
end
return M
