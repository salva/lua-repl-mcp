local codec=require('lua_repl_mcp.codec')
local errors=require('lua_repl_mcp.errors')
local null=require('lua_repl_mcp').null
local M={}
local creation={cwd=true,stdin_path=true,stdout_path=true,stderr_path=true}
local tools={
 session_create=creation,
 session_execute={code=true,args=true,session_id=true,wait_timeout_ms=true,execution_timeout_ms=true,create_options=true},
 session_wait={session_id=true,wait_timeout_ms=true}, session_kill={session_id=true},
 session_list={},repl_execute={code=true,args=true},repl_close={}
}
local function invalid(path,reason) error({path=path,reason=reason},0) end
local function object(t,path,fields)
  if type(t)~='table' or rawequal(t,null) or codec.kind(t)=='array' then invalid(path,'expected object') end
  for k in next,t do
    if type(k)~='string' then invalid(path,'non-string object key') end
    if not fields[k] then invalid(codec.pointer(path,k),'unknown field') end
  end
end
local function stringfield(t,k,required,nonempty,path)
  local v=rawget(t,k)
  if v==nil and not required then return end
  if type(v)~='string' or (nonempty and #v==0) or not codec.valid_utf8(v) then
    invalid(codec.pointer(path,k),'expected '..(nonempty and 'nonempty ' or '')..'UTF-8 string')
  end
end
local function create(t,path)
  object(t,path,creation)
  for k in next,creation do stringfield(t,k,false,true,path) end
end
local function timeout(v,min,path)
  if rawequal(v,null) then return end
  if type(v)~='number' or v%1~=0 or v<min or v>2147483647 then invalid(path,'invalid timeout') end
end
function M.validate(tool,input)
  local ok,result=pcall(function()
    local fields=tools[tool]; if not fields then invalid('','unknown tool') end
    object(input,'',fields)
    -- Copy only after structural validation, rejecting unsupported data even in
    -- nested args. No untrusted conversion or indexing metamethod is invoked.
    local copy,e=codec.clone(input)
    if not copy then invalid(e.path,e.reason) end
    if tool=='session_create' then create(copy,'') end
    if tool=='repl_execute' or tool=='session_execute' then
      stringfield(copy,'code',true,false,'')
      if copy.args==nil then copy.args=codec.array({}) end
      if type(copy.args)~='table' or rawequal(copy.args,null) or codec.kind(copy.args)~='array' then invalid('/args','expected array') end
    end
    if tool=='session_execute' then
      if copy.session_id==nil then copy.session_id=null end
      if not rawequal(copy.session_id,null) then stringfield(copy,'session_id',true,true,'') end
      if copy.execution_timeout_ms==nil then copy.execution_timeout_ms=null end
      timeout(copy.execution_timeout_ms,1,'/execution_timeout_ms')
      if copy.create_options~=nil then
        if not rawequal(copy.session_id,null) then invalid('/create_options','requires null session_id') end
        create(copy.create_options,'/create_options')
      end
    elseif tool=='session_wait' or tool=='session_kill' then stringfield(copy,'session_id',true,true,'') end
    if tool=='session_execute' or tool=='session_wait' then
      if copy.wait_timeout_ms==nil then copy.wait_timeout_ms=600000 end
      timeout(copy.wait_timeout_ms,0,'/wait_timeout_ms')
    end
    return copy
  end)
  if ok then return result end
  return nil,errors.new('invalid_arguments',result.reason,'validation','not_started',{path=result.path})
end
function M.from_json(tool,text)
  local data,e=codec.decode(text)
  if data==nil then return nil,errors.new('invalid_arguments',e.reason,'validation','not_started',{path=e.path}) end
  return M.validate(tool,data)
end
return M
