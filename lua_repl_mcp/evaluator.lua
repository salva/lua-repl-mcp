local codec=require('lua_repl_mcp.codec')
local errors=require('lua_repl_mcp.errors')
local contracts=require('lua_repl_mcp.contracts')
local null=require('lua_repl_mcp').null
local limits=require('lua_repl_mcp.limits')
-- Capture primitives before running user code. The evaluator is not a sandbox;
-- ordinary mutation of host globals must not change its bookkeeping mid-call.
local load, xpcall, pack, unpack, traceback = load, xpcall, table.pack, table.unpack, debug.traceback
local M={}
function M.execute(input,options)
  options=limits.evaluator(options)
  local args,e=contracts.validate('repl_execute',input)
  if not args then return errors.failure(e) end
  local function err(code,msg,stage,state,extra)
    return errors.failure(errors.new(code,msg,stage,state,extra,options.diagnostic_bytes))
  end
  local f,compile_error=load(args.code,'=(repl)','t',_G)
  if not f then return err('lua_syntax_error',compile_error,'execution','not_started') end
  local thrown,trace
  local result=pack(xpcall(f,function(v)
    thrown=v; trace=traceback('',2); return v
  end,unpack(args.args,1,#args.args)))
  if not result[1] then return err('lua_runtime_error',thrown,'execution','started',{traceback=trace}) end
  local values=codec.array({})
  for i=2,result.n do
    local v=result[i]
    values[i-1]=v==nil and null or v
  end
  -- Validate each user value with the user-table mapping, while keeping the
  -- return list an explicit JSON array (including the zero-return case).
  local fragments={}
  local bytes=2
  for i=1,result.n-1 do
    local s,problem=codec.encode(values[i],{user_tables=true,path='/values/'..(i-1),max_depth=options.max_depth,max_bytes=options.max_bytes})
    if not s then return err('result_serialization_error',problem.reason..'; execution completed; side effects were not rolled back','serialization','completed',{path=problem.path}) end
    bytes=bytes+#s+(i>1 and 1 or 0)
    if bytes>(options.max_bytes or 16*1024*1024) then
      return err('result_serialization_error','serialized values size limit exceeded; execution completed; side effects were not rolled back','serialization','completed',{path='/values'})
    end
    fragments[i]=s
  end
  if bytes>(options.max_bytes or 16*1024*1024) then
    return err('result_serialization_error','serialized values size limit exceeded; execution completed; side effects were not rolled back','serialization','completed',{path='/values'})
  end
  -- Decode once, not execute again: detach response data from user tables and
  -- normalize empty input arrays returned by user code to objects.
  local normalized=assert(codec.decode('['..table.concat(fragments,',')..']',{
    max_bytes=options.max_bytes or 16*1024*1024,max_depth=(options.max_depth or 128)+1}))
  return {status='completed',values=normalized}
end
function M.from_json(text,options)
  local input,e=contracts.from_json('repl_execute',text)
  if not input then return errors.failure(e) end
  return M.execute(input,options)
end
return M
