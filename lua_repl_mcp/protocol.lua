-- Shared MCP protocol state, independent of adapters and lifecycle policy.
local codec=require('lua_repl_mcp.codec')
local contracts=require('lua_repl_mcp.contracts')
local null=require('lua_repl_mcp').null
local M={version='2025-11-25'}
local function object(v) return type(v)=='table' and v~=null and codec.kind(v)~='array' end
local function rpc(id,code,message)
  return {jsonrpc='2.0',id=id or null,error={code=code,message=message}}
end
-- The values budget is not a payload/envelope budget. In particular metadata
-- must not make an otherwise legal maximum values array fail wrapping.
function M.tool_result(payload,options)
  options=options or {max_bytes=128*1048576,max_depth=160}
  local text,err=codec.encode(payload,options)
  if not text then return nil,err end
  return {structuredContent=payload,content=codec.array({{type='text',text=text}}),isError=payload.error~=nil}
end
-- Budget the entire frame before any write or single-consumer commitment.
-- A replacement does not claim the original result: callers must preserve it.
function M.encode_result(id,payload,options,tool)
  options=options or {max_bytes=128*1048576,max_depth=160}
  local result=M.tool_result(payload,options)
  local encoded=result and codec.encode({jsonrpc='2.0',id=id,result=result},options)
  if encoded then return encoded,true end
  local errors=require('lua_repl_mcp.errors')
  -- An overflow is not necessarily an execution result (list/create/kill and
  -- close forbid status=failed). Error-only is valid for every tool. Retain
  -- execution/session context when the original result has it.
  local fallback_payload={error=errors.new('limit_exceeded',
    'Complete response exceeds configured bound','serialization',
    payload.error and payload.error.execution_state or
    ((payload.status=='completed' or payload.status=='failed') and 'completed' or 'not_started'))}
  for _,key in ipairs({'session_id','session_status','session_usable','process_exit_confirmed','notice'}) do
    if tool~='session_create' and tool~='session_list' then fallback_payload[key]=payload[key] end
  end
  result=M.tool_result(fallback_payload,{max_bytes=128*1048576,max_depth=160})
  local fallback,err=codec.encode({jsonrpc='2.0',id=id,result=result},options)
  return fallback,false,err
end
function M.new(config)
  local self={state='new'}
  function self:handle(text)
    local r=codec.decode(text,{max_depth=(config.max_depth or 128)+4,max_bytes=config.input_bytes})
    if r==nil then return rpc(nil,-32700,'Parse error') end
    if not object(r) or r.jsonrpc~='2.0' or type(r.method)~='string' or
      (r.id~=nil and (type(r.id)~='string' and type(r.id)~='number')) or
      (r.params~=nil and not object(r.params) and codec.kind(r.params)~='array') then
      return rpc(nil,-32600,'Invalid Request')
    end
    local id=r.id
    if id==nil then
      if r.method=='notifications/initialized' and self.state=='initializing' then self.state='ready' end
      -- Cancellation cannot interrupt a synchronous direct execution, nor kill a host.
      if config.notification then config.notification(r) end
      return nil
    end
    -- Outstanding IDs remain reserved through response enqueue. Check before
    -- every ID-bearing dispatch, including ping and initialization.
    if config.outstanding and config.outstanding(id) then
      return rpc(nil,-32600,'Duplicate outstanding request ID')
    end
    local function ok(value) return {jsonrpc='2.0',id=id,result=value} end
    if r.method=='ping' then return ok(codec.object({})) end
    if r.method=='initialize' then
      if self.state~='new' then return rpc(id,-32600,'Already initialized') end
      local p=r.params
      if not object(p) or type(p.protocolVersion)~='string' or not object(p.capabilities) or
        not object(p.clientInfo) or type(p.clientInfo.name)~='string' or type(p.clientInfo.version)~='string' then
        return rpc(id,-32602,'Invalid initialization parameters')
      end
      self.state='initializing'
      return ok({protocolVersion=M.version,capabilities={tools=codec.object({})},
        serverInfo={name='lua-repl-mcp',version='0.1.0'},instructions=config.instructions})
    end
    if self.state~='ready' then return rpc(id,-32600,'Initialization required') end
    if r.method=='tools/list' then return ok({tools=config.tools}) end
    if r.method~='tools/call' then return rpc(id,-32601,'Method not found') end
    local p=r.params
    if not object(p) or type(p.name)~='string' then return rpc(id,-32602,'Invalid tool call') end
    if not config.names[p.name] then return rpc(id,-32602,'Unknown tool') end
    -- Only omission selects defaults; explicit false/null/scalars must reach
    -- validation unchanged and must never trigger a lifecycle action.
    local input=p.arguments
    if input==nil then input=codec.object({}) end
    if config.submit then
      config.submit(id,p.name,input,assert(codec.json_data(text,{max_depth=(config.max_depth or 128)+4,max_bytes=config.input_bytes})))
      return nil
    end
    local args,e=contracts.validate(p.name,input,{max_depth=config.max_depth or 128})
    if not args then
      return ok(M.tool_result(p.name=='repl_execute' and require('lua_repl_mcp.errors').failure(e) or {error=e}))
    end
    local payload,action=config.call(p.name,args)
    return ok(M.tool_result(payload,{max_depth=(config.max_depth or 128)+2,max_bytes=128*1048576})),action,id
  end
  return self
end
M.error=rpc
return M
