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
  options=options or {max_bytes=64*1048576,max_depth=160}
  local text,err=codec.encode(payload,options)
  if not text then return nil,err end
  return {structuredContent=payload,content=codec.array({{type='text',text=text}}),isError=payload.error~=nil}
end
-- Budget the entire frame before any write or single-consumer commitment.
-- A replacement does not claim the original result: callers must preserve it.
function M.encode_result(id,payload,options)
  options=options or {max_bytes=64*1048576,max_depth=160}
  local result=M.tool_result(payload,options)
  local encoded=result and codec.encode({jsonrpc='2.0',id=id,result=result},options)
  if encoded then return encoded,true end
  local errors=require('lua_repl_mcp.errors')
  result=M.tool_result(errors.failure(errors.new('limit_exceeded',
    'Complete response exceeds configured bound','serialization','completed')),
    {max_bytes=64*1048576,max_depth=160})
  local fallback,err=codec.encode({jsonrpc='2.0',id=id,result=result},options)
  return fallback,false,err
end
function M.new(config)
  local self={state='new'}
  function self:handle(text)
    local r=codec.decode(text)
    if not r then return rpc(nil,-32700,'Parse error') end
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
    local args,e=contracts.validate(p.name,input)
    if not args then
      return ok(M.tool_result(require('lua_repl_mcp.errors').failure(e)))
    end
    local payload,action=config.call(p.name,args)
    return ok(M.tool_result(payload)),action,id
  end
  return self
end
M.error=rpc
return M
