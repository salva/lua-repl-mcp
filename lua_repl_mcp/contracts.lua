local codec=require('lua_repl_mcp.codec')
local errors=require('lua_repl_mcp.errors')
local null=require('lua_repl_mcp').null
local M={}
local creation={cwd=true,stdin_path=true,stdout_path=true,stderr_path=true,command=true}
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
  for k in next,creation do
    if k~='command' then
      stringfield(t,k,false,true,path)
      if t[k] and t[k]:find('\0',1,true) then invalid(codec.pointer(path,k),'path contains NUL') end
    end
  end
  local argv=rawget(t,'command')
  if argv~=nil then
    local p=codec.pointer(path,'command')
    if type(argv)~='table' or codec.kind(argv)~='array' or #argv==0 then invalid(p,'expected nonempty argv array') end
    for i,v in ipairs(argv) do
      if type(v)~='string' or (i==1 and #v==0) or not codec.valid_utf8(v) or v:find('\0',1,true) then
        invalid(codec.pointer(p,i-1),'invalid command argument')
      end
    end
  end
end
local function timeout(v,min,path)
  if rawequal(v,null) then return end
  if type(v)~='number' or v%1~=0 or v<min or v>2147483647 then invalid(path,'invalid timeout') end
end
function M.validate(tool,input,options)
  options=options or {}
  local depth=options.max_depth or 128
  local ok,result=pcall(function()
    local fields=tools[tool]; if not fields then invalid('','unknown tool') end
    object(input,'',fields)
    -- Copy only after structural validation, rejecting unsupported data even in
    -- nested args. No untrusted conversion or indexing metamethod is invoked.
    -- Tool object and positional tuple are two fixed containers, not user
    -- nesting. Validate each user value below against its own D allowance.
    local copy,e=codec.clone(input,{max_depth=depth+2,max_bytes=options.max_bytes,checkpoint=options.checkpoint})
    if not copy then invalid(e.path,e.reason) end
    if tool=='session_create' then create(copy,'') end
    if tool=='repl_execute' or tool=='session_execute' then
      stringfield(copy,'code',true,false,'')
      if copy.args==nil then copy.args=codec.array({}) end
      if type(copy.args)~='table' or rawequal(copy.args,null) or codec.kind(copy.args)~='array' then invalid('/args','expected array') end
    end
    if copy.args then
      local work=0
      local function nested(v,n,path)
        work=work+1
        if options.checkpoint and work>=65536 then work=0; options.checkpoint() end
        if type(v)~='table' or rawequal(v,null) then return end
        if n>depth then invalid(path,'nesting limit exceeded') end
        for k,child in next,v do nested(child,n+1,codec.pointer(path,k)) end
      end
      for i,v in ipairs(copy.args) do nested(v,1,'/args/'..(i-1)) end
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
function M.from_json(tool,text,options)
  options=options or {}
  local data,e=codec.decode(text,{max_depth=(options.max_depth or 128)+2,max_bytes=options.max_bytes,checkpoint=options.checkpoint})
  if data==nil then return nil,errors.new('invalid_arguments',e.reason,'validation','not_started',{path=e.path}) end
  -- Raw ingress bytes were charged by decode. Canonical escapes may expand;
  -- keep fresh structure/depth validation without admitting the same data twice.
  return M.validate(tool,data,{max_depth=options.max_depth,max_bytes=math.huge,checkpoint=options.checkpoint})
end
return M
