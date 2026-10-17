-- Blocking, invoking-thread attachment. The parent owns all resources.
local codec=require('lua_repl_mcp.codec')
local framing=require('lua_repl_mcp.framing')
local protocol=require('lua_repl_mcp.protocol')
local evaluator=require('lua_repl_mcp.evaluator')
local M={}
function M.serve(adapter,options)
  local frames=framing.new(16*1048576)
  local result={reason='handler_error',acknowledgement_sent=false}
  local function finish(reason,diagnostics)
    result.reason=reason; result.diagnostics=diagnostics
    result.pending_messages,result.pending_bytes=frames:handoff()
    return result
  end
  local function run()
    options=options or {}
    assert(type(options)=='table','options must be a table')
    local allowed={input_bytes=true,response_bytes=true,read_bytes=true,evaluator=true,instructions=true}
    for k in pairs(options) do assert(allowed[k],'unknown handler option') end
    for _,k in ipairs({'input_bytes','response_bytes','read_bytes'}) do
      if options[k]~=nil then assert(math.type(options[k])=='integer' and options[k]>0,'invalid handler limit') end
    end
    frames.limit=options.input_bytes or frames.limit
    local read_bytes=options.read_bytes or 65536
    local response_bytes=options.response_bytes or 128*1048576
    local eval_options=require('lua_repl_mcp.limits').evaluator(options.evaluator)
    assert(options.instructions==nil or (type(options.instructions)=='string' and codec.valid_utf8(options.instructions)),'invalid instructions')
    assert(type(adapter)=='table','invalid adapter')
    for _,k in ipairs({'read','write','flush'}) do assert(type(adapter[k])=='function','missing adapter function: '..k) end
    local function io_call(name,...)
      local ok,v,e=pcall(adapter[name],...)
      if not ok then return nil,'adapter '..name..' raised an error' end
      return v,e
    end
    local function send(response)
      local encoded=codec.encode(response,{max_depth=eval_options.max_depth+32,max_bytes=response_bytes})
      local original=encoded~=nil
      if not encoded then
        local errors=require('lua_repl_mcp.errors')
        response={jsonrpc='2.0',id=response.id,result=protocol.tool_result(errors.failure(errors.new(
          'limit_exceeded','Complete response exceeds configured bound','serialization','completed')))}
        encoded=assert(codec.encode(response,{max_bytes=response_bytes}))
      end
      local bytes=encoded..'\n'
      local pos=1
      while pos<=#bytes do
        local tail=bytes:sub(pos)
        local n,e=io_call('write',tail)
        if math.type(n)~='integer' or n<=0 or n>#tail then return nil,e or 'invalid write progress' end
        pos=pos+n
      end
      local ok,e=io_call('flush')
      if ok~=true then return nil,e or 'invalid flush result' end
      return true,nil,original
    end
    local core=protocol.new({
      tools=assert(codec.decode(require('lua_repl_mcp.direct_schemas'))),
      names={repl_execute=true,repl_close=true},
      instructions=options.instructions or 'Trusted code runs in the host global environment. Explicit return is required. Close returns control to the parent; no host termination or managed cancellation.',
      call=function(name,args)
        if name=='repl_close' then return {status='closing'},'close' end
        return evaluator.execute(args,eval_options)
      end,
    })
    while true do
      local frame,problem=frames:pop()
      if problem then return finish('handler_error',problem) end
      if frame then
        local response,action,id=core:handle(frame)
        if action=='close' then result.close_request_id=id end
        if response then
          local ok,e,original=send(response)
          if not ok then return finish(action=='close' and 'close_requested' or 'transport_error',e) end
          if action=='close' then
            result.acknowledgement_sent=original
            return finish('close_requested',not original and 'close acknowledgement exceeded response bound' or nil)
          end
        end
      else
        -- Read no more than the remaining frame bound plus a delimiter byte.
        local n=math.min(read_bytes,frames.limit-#frames.buffer+1)
        local bytes,e=io_call('read',n)
        if bytes==nil then
          if e=='eof' then return finish('eof') end
          return finish('transport_error',e or 'invalid read result')
        end
        if type(bytes)~='string' or #bytes==0 or #bytes>n then return finish('transport_error','invalid read progress') end
        frames:feed(bytes)
      end
    end
  end
  local ok,value=pcall(run)
  if ok then return value end
  return finish('handler_error',type(value)=='string' and value or 'unrecoverable handler error')
end
return M
