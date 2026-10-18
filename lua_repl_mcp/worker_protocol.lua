-- Private protocol, deliberately independent of POSIX and public MCP framing.
local c=require('lua_repl_mcp.codec')
local M={version=1,max_frame=64*1024*1024}
local fields={
 file_created={path='string'}, ready={cwd='optional_string'},
 startup_error={reason='string',message='string'},
 execute={execution_generation='integer',input='optional_table',request='optional_table'},
 result={execution_generation='integer',result='table'}, close={}}
local function integer(v) return type(v)=='number' and math.type(v)=='integer' and v>0 end
local function enum(words)
 local values={}; for word in words:gmatch('%S+') do values[word]=true end
 return function(v) return type(v)=='string' and values[v]==true end
end
local function string_value(v) return type(v)=='string' end
local function boolean(v) return type(v)=='boolean' end
-- Validate nested errors before recording a consumable result, not at output.
-- These fields mirror the public error contract in docs/schemas/api.json.
local error_fields={
 code=enum('invalid_arguments unknown_session session_busy session_terminating no_execution result_unavailable session_limit session_creation_error lua_syntax_error lua_runtime_error result_serialization_error execution_timeout session_killed request_cancelled worker_exited transport_error limit_exceeded'),
 message=string_value,
 stage=enum('validation creation execution serialization transport termination'),
 execution_state=enum('not_started started completed unknown'),
 traceback=string_value,
 path=function(v) return type(v)=='string' and (v=='' or v:sub(1,1)=='/') end,
 reason=enum('startup_timeout spawn_failed cwd_setup_failed stdio_setup_failed handshake_failed'),
 data_preserved=boolean,truncated=boolean,invalid_bytes_escaped=boolean,
 exit_code=function(v) return type(v)=='number' and v%1==0 and v>=0 and v<math.huge end,
 signal=function(v) return type(v)=='number' and v%1==0 and v>=1 and v<math.huge end,
 created_files=function(v)
  if type(v)~='table' or c.kind(v)~='array' then return false end
  for _,path in pairs(v) do if type(path)~='string' then return false end end
  return true
 end,
 created_files_complete=boolean,process_exit_confirmed=boolean}
local function valid_error(e)
 if type(e)~='table' or e==require('lua_repl_mcp').null or c.kind(e)=='array' then return false end
 for _,k in ipairs({'code','message','stage','execution_state'}) do
  if e[k]==nil then return false end
 end
 for k,v in pairs(e) do
  if not error_fields[k] or not error_fields[k](v) then return false end
 end
 return true
end
-- The complete original body remains JSON data; public IDs never dispatch work.
function M.execution_arguments(request,limits,checkpoint)
  local r=c.json_value(request,checkpoint)
  if not r or c.json_bytes(request)>(limits and limits.input_bytes or 16*1048576) or
   r.jsonrpc~='2.0' or r.method~='tools/call' or type(r.params)~='table' or
   r.params.name~='session_execute' then return nil,'invalid original request' end
  local a=require('lua_repl_mcp.contracts').validate('session_execute',r.params.arguments,
   {max_depth=limits and limits.max_depth or 128,max_bytes=math.huge,checkpoint=checkpoint})
  if not a then return nil,'invalid original arguments' end
  return a
end
-- Creation derives its options only from the immutable bounded ingress body.
function M.creation_arguments(request,limits)
 local r=c.json_value(request)
 if not r or c.json_bytes(request)>limits.input_bytes or r.jsonrpc~='2.0' or
  r.method~='tools/call' or type(r.params)~='table' then return nil,'invalid original creation' end
 local tool=r.params.name
 if tool~='session_create' and tool~='session_execute' then return nil,'invalid creation tool' end
 local input=r.params.arguments
 if input==nil then input={} end
 local a,e=require('lua_repl_mcp.contracts').validate(tool,input,
  {max_depth=limits.max_depth,max_bytes=math.huge})
 if not a then return nil,e end
 if tool=='session_execute' then
  if a.session_id~=require('lua_repl_mcp').null then return nil,'not implicit creation' end
  return a.create_options or {}
 end
 return a
end
function M.execution_input(v,limits,checkpoint)
 if v.request then
  if v.input then return nil,'conflicting execution representation' end
  local a,e=M.execution_arguments(v.request,limits,checkpoint)
  if not a then return nil,e end
  return {code=a.code,args=a.args}
 end
 if not v.input then return nil,'missing execution representation' end
 return v.input
end
function M.validate(v,limits,checkpoint)
 if type(v)~='table' or c.kind(v)=='array' then return nil,'expected record' end
 local spec=fields[v.type]
 if not spec or v.protocol_version~=1 or not integer(v.allocation_generation) then return nil,'invalid envelope' end
 for k in pairs(v) do
  if k~='type' and k~='protocol_version' and k~='allocation_generation' and not spec[k] then return nil,'unknown field' end
 end
 for k,t in pairs(spec) do
  if (t=='optional_string' and v[k]~=nil and (type(v[k])~='string' or v[k]:sub(1,1)~='/')) or
     (t=='optional_table' and v[k]~=nil and type(v[k])~='table') or
     (t=='integer' and not integer(v[k])) or
     (t~='integer' and t~='optional_string' and t~='optional_table' and type(v[k])~=t) then return nil,'invalid '..k end
 end
 if v.type=='execute' then
  local input,e=M.execution_input(v,limits,checkpoint)
  if not input then return nil,e end
  local args=require('lua_repl_mcp.contracts').validate('repl_execute',input,{max_depth=limits and limits.max_depth or 128,max_bytes=v.request and math.huge or (limits and limits.input_bytes or 16*1048576),checkpoint=checkpoint})
  if not args then return nil,'invalid execution input' end
 end
 if v.type=='startup_error' and v.reason~='spawn_failed' and v.reason~='cwd_setup_failed' and v.reason~='stdio_setup_failed' and v.reason~='handshake_failed' then return nil,'invalid startup reason' end
 if v.type=='result' then
  local r=v.result
  if r.status~='completed' and r.status~='failed' then return nil,'invalid result' end
  for k in pairs(r) do if k~='status' and k~='values' and k~='error' then return nil,'unknown result field' end end
  if (r.status=='completed' and r.error~=nil) or (r.status=='failed' and r.values~=nil) then return nil,'conflicting result' end
  if r.status=='completed' and (type(r.values)~='table' or c.kind(r.values)~='array') then return nil,'invalid values' end
  if r.status=='failed' and not valid_error(r.error) then return nil,'invalid error' end
 end
 return v
end
function M.record(kind,g,extra)
 local v=extra or {}; v.type=kind; v.protocol_version=1; v.allocation_generation=g; return v
end
function M.encode(v,limits,checkpoint)
 local ok,e=M.validate(v,limits,checkpoint); if not ok then return nil,e end
 local s,err=c.encode(v,{max_bytes=(limits and limits.worker_bytes or M.max_frame),max_depth=(limits and limits.max_depth or 128)+5,checkpoint=checkpoint}); if not s then return nil,err end
 if #s>(limits and limits.worker_bytes or M.max_frame) then return nil,'frame too large' end
 return s..'\n'
end
function M.decode(s,limits,checkpoint)
 if #s>(limits and limits.worker_bytes or M.max_frame) then return nil,'frame too large' end
 local v,e=c.decode(s,{max_bytes=(limits and limits.worker_bytes or M.max_frame),max_depth=(limits and limits.max_depth or 128)+5,json_path="/request",checkpoint=checkpoint}); if not v then return nil,e end
 return M.validate(v,limits,checkpoint)
end
return M
