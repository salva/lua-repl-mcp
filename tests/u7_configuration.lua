local limits=require('lua_repl_mcp.limits')
local manager=require('lua_repl_mcp.manager')
local transport=require('lua_repl_mcp.client_transport')
local p=require('lua_repl_mcp.worker_protocol')
local c=require('lua_repl_mcp.codec')
local base={input_bytes=4096,values_bytes=1024,diagnostic_bytes=256,max_depth=8,
 worker_bytes=1055232,response_bytes=4218368,output_bytes=4218369}
local function options(k,v)
 local r={}; for a,b in pairs(base) do r[a]=b end; if k then r[k]=v end; return r
end
for _,field in ipairs({'worker_bytes','response_bytes','output_bytes'}) do
 for _,delta in ipairs({-1,0,1}) do
  local ok=pcall(limits.connection,options(field,base[field]+delta))
  -- Raising response alone requires raising output too.
  if field=='response_bytes' and delta==1 then assert(not ok)
  else assert(ok==(delta>=0)) end
 end
end
for _,bad in ipairs({{unknown=1},{values_bytes=0},{max_depth=513},{diagnostic_bytes=1},
 {input_bytes=false},{response_bytes=math.huge}}) do assert(not pcall(limits.connection,bad)) end
local defaults=limits.connection()
assert(defaults.default_fit_unresolved==nil and defaults.response_bytes==128*1048576)
assert(p.max_frame==64*1048576)
local b={clock=function() return 0 end,step=function() end,shutdown=function() return true end}
local m=manager.new{limits=base,supervisor=b}
local t=transport.new(m,{})
assert(t.input.limit==4096 and t.response_bytes==4218368 and t.output_bytes==4218369 and t.encode_depth==40)
assert(not pcall(transport.new,m,{}, {input_bytes=8192}))
local text=assert(p.encode(p.record('result',1,{execution_generation=1,
 result={status='completed',values=c.array({string.rep('x',1020)})}}),m.limits))
assert(p.decode(text:sub(1,-2),m.limits))
assert(not p.decode(string.rep('x',base.worker_bytes+1),m.limits))
assert(p.max_frame==64*1048576,'per-instance configuration must not mutate default protocol')
print('PASS configured_coupled_boundaries_validation_inheritance_and_protocol_isolation')
local explicit={input_bytes=16777216,values_bytes=16777216,diagnostic_bytes=65536,
 max_depth=128,worker_bytes=67108864,response_bytes=134217728,output_bytes=268435456}
assert(limits.connection(explicit).default_fit_unresolved==nil)
-- Distinct small input/large result is supported, not accidentally constrained
-- by the public input codec. Constructor arithmetic also supports >16 MiB values.
local big=limits.connection{input_bytes=8192,values_bytes=20*1048576,
 worker_bytes=24*1048576,response_bytes=80*1048576,output_bytes=128*1048576}
assert(big.values_bytes>big.input_bytes)
local mut=options(); local owned=manager.new{limits=mut,supervisor=b}
mut.values_bytes=99
assert(owned.limit_options.values_bytes==1024 and owned.limits.values_bytes==1024)
local bad_backend={limits=limits.connection(),clock=function() return 0 end}
assert(not pcall(manager.new,{limits=base,supervisor=bad_backend}))
