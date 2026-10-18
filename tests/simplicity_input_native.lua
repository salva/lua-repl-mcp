-- Current real creation ingress and oversized-result session recovery.
local c=require('lua_repl_mcp.codec')
local G=require('lua_repl_mcp.guardian')
local M=require('lua_repl_mcp.manager')
local x=require('lua_repl_mcp.worker_posix')
local limits={input_bytes=256,values_bytes=16,diagnostic_bytes=49,worker_bytes=1049142,response_bytes=4196258,output_bytes=4196259,max_depth=1}
local b=G.new{limits=limits}; local m=M.new{supervisor=b,limits=limits}
local function take(r)
 local stop=x.now()+12
 repeat local v=m:commit(r,function() return true end); if v then return v end
  m:step(0); assert(x.now()<stop,'input/recovery watchdog') until false
end
local function original(tool,args)
 local text=assert(c.encode{jsonrpc='2.0',id=1,method='tools/call',params={name=tool,arguments=args}}):gsub('\\u0009','\\t')
 assert(#text<=256)
 return assert(c.json_data(text))
end
local ok,err=pcall(function()
 local before=b.generation
 local rejected=take(m:accept('session_create',{},nil,original('session_create',false)))
 assert(rejected.error.code=='invalid_arguments' and b.generation==before)
 local library=take(m:accept('session_create',{cwd=string.rep('\t',60)}))
 assert(library.error.code=='invalid_arguments' and b.generation==before)
 print('PASS invalid_original_false_and_library_canonical_budget_reject_before_allocate')
 -- Compact tab escapes expand from 2 bytes to canonical 6; valid raw ingress
 -- still creates an allocation and reaches actual cwd failure, not re-admission.
 for _,implicit in ipairs{false,true} do
  local tool=implicit and 'session_execute' or 'session_create'
  local args=implicit and {code='return 1',create_options={cwd=string.rep('\t',43)}} or {cwd=string.rep('\t',60)}
  local v=take(m:accept(tool,{},nil,original(tool,args)))
  assert(v.error and v.error.reason=='cwd_setup_failed',v.error and v.error.message)
  assert(v.process_exit_confirmed)
  print('PASS tight_floor_'..tool..'_original_expanded_cwd_actual_native_failure')
 end
 local id=assert(take(m:accept('session_create',{})).session_id)
 for _,character in ipairs{'x','"'} do
  local code='effect=73; return {[string.rep('..string.format('%q',character)..',1100000)]=function() end}'
  local v=take(m:accept('session_execute',{session_id=id,code=code}))
  assert(v.error.code=='result_serialization_error' and v.error.execution_state=='completed' and v.session_usable and not v.error.path)
  local next=take(m:accept('session_execute',{session_id=id,code='return effect'}))
  assert(next.values[1]==73)
  print('PASS oversized_optional_path_native_completed_effect_session_recovery_'..string.byte(character))
 end
end)
local clean=b:shutdown()
assert(ok,err); assert(clean)
local pid,_,errno=x.w.wait(b.guardian_pid,x.w.WNOHANG)
assert(pid==nil and errno==x.e.ECHILD)
print('PASS input_recovery_owned_reap_before_cleanup')
