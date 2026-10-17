local x=require('lua_repl_mcp.worker_posix')
local p=require('lua_repl_mcp.worker_protocol')
local codec=require('lua_repl_mcp.codec')
local evaluator=require('lua_repl_mcp.evaluator')
local M={}
function M.run(input,output,g,options,limit_options)
 local limits=require('lua_repl_mcp.limits').connection(limit_options)
 local framing=require('lua_repl_mcp.framing').new(limits.worker_bytes)
 x.clo(input,true); x.clo(output,true)
 local function send(kind,extra)
  return x.write_all(output,assert(p.encode(p.record(kind,g,extra),limits)))
 end
 local function setup()
  if options.cwd then assert(x.u.chdir(options.cwd)) end
  local cwd=assert(x.u.getcwd())
  local function open(path,flags,report)
   local fd,msg=x.f.open(path,flags,tonumber('600',8)); assert(fd,msg)
   if report then
    local absolute=path:sub(1,1)=='/' and path or cwd..'/'..path
    assert(send('file_created',{path=absolute}))
   end
   return fd
  end
  local out=open(options.stdout_path or '/dev/null',options.stdout_path and (x.f.O_WRONLY|x.f.O_CREAT|x.f.O_EXCL) or x.f.O_WRONLY,options.stdout_path)
  assert(x.u.dup2(out,1)); x.u.close(out)
  if options.stderr_path and options.stderr_path==options.stdout_path then
   assert(x.u.dup2(1,2))
  else
   local err=open(options.stderr_path or '/dev/null',options.stderr_path and (x.f.O_WRONLY|x.f.O_CREAT|x.f.O_EXCL) or x.f.O_WRONLY,options.stderr_path)
   assert(x.u.dup2(err,2)); x.u.close(err)
  end
  local inp=open(options.stdin_path or '/dev/null',x.f.O_RDONLY,false)
  assert(x.u.dup2(inp,0)); x.u.close(inp)
 end
 local ok,msg=pcall(setup)
 if not ok then send('startup_error',{reason='stdio_setup_failed',message=tostring(msg)}); return end
 if not send('ready',{cwd=assert(x.u.getcwd())}) then return end
 local last=0
 while true do
  local chunk,_,err=x.u.read(input,65536)
  if not chunk then if err~=x.e.EINTR then return end
  elseif chunk=='' then return
  else
   if not framing:feed(chunk) then return end
   while true do
    local frame,err=framing:pop()
    if err then return end
    if not frame then break end
    local v=p.decode(frame,limits)
    if not v or v.allocation_generation~=g then return end
    if v.type=='close' then return end
    if v.type~='execute' or v.execution_generation~=last+1 then return end
    if not require('lua_repl_mcp.contracts').validate('repl_execute',v.input) then return end
    last=v.execution_generation
    local result=evaluator.execute(v.input,{max_bytes=limits.values_bytes,max_depth=limits.max_depth,diagnostic_bytes=limits.diagnostic_bytes})
    if not send('result',{execution_generation=last,result=result}) then return end
   end
  end
 end
end
-- Standard wrapper owns process lifetime, unlike the embedded handler.
function M.main(...) local ok=pcall(M.run,...); x.u._exit(ok and 0 or 1) end
return M
