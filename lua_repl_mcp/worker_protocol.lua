-- Private protocol, deliberately independent of POSIX and public MCP framing.
local c=require('lua_repl_mcp.codec')
local M={version=1,max_frame=20*1024*1024}
local fields={
 file_created={path='string'}, ready={},
 startup_error={reason='string',message='string'},
 execute={execution_generation='integer',input='table'},
 result={execution_generation='integer',result='table'}, close={}}
local function integer(v) return type(v)=='number' and math.type(v)=='integer' and v>0 end
function M.validate(v)
 if type(v)~='table' or c.kind(v)=='array' then return nil,'expected record' end
 local spec=fields[v.type]
 if not spec or v.protocol_version~=1 or not integer(v.allocation_generation) then return nil,'invalid envelope' end
 for k in pairs(v) do
  if k~='type' and k~='protocol_version' and k~='allocation_generation' and not spec[k] then return nil,'unknown field' end
 end
 for k,t in pairs(spec) do
  if (t=='integer' and not integer(v[k])) or (t~='integer' and type(v[k])~=t) then return nil,'invalid '..k end
 end
 if v.type=='execute' then
  local args=require('lua_repl_mcp.contracts').validate('repl_execute',v.input)
  if not args then return nil,'invalid execution input' end
 end
 if v.type=='startup_error' and v.reason~='spawn_failed' and v.reason~='stdio_setup_failed' and v.reason~='handshake_failed' then return nil,'invalid startup reason' end
 if v.type=='result' then
  local r=v.result
  if r.status~='completed' and r.status~='failed' then return nil,'invalid result' end
  for k in pairs(r) do if k~='status' and k~='values' and k~='error' then return nil,'unknown result field' end end
  if (r.status=='completed' and r.error~=nil) or (r.status=='failed' and r.values~=nil) then return nil,'conflicting result' end
  if r.status=='completed' and (type(r.values)~='table' or c.kind(r.values)~='array') then return nil,'invalid values' end
  if r.status=='failed' and type(r.error)~='table' then return nil,'invalid error' end
 end
 return v
end
function M.record(kind,g,extra)
 local v=extra or {}; v.type=kind; v.protocol_version=1; v.allocation_generation=g; return v
end
function M.encode(v)
 local ok,e=M.validate(v); if not ok then return nil,e end
 local s,err=c.encode(v,{max_bytes=M.max_frame,max_depth=140}); if not s then return nil,err end
 if #s>M.max_frame then return nil,'frame too large' end
 return s..'\n'
end
function M.decode(s)
 if #s>M.max_frame then return nil,'frame too large' end
 local v,e=c.decode(s,{max_bytes=M.max_frame,max_depth=140}); if not v then return nil,e end
 return M.validate(v)
end
return M
