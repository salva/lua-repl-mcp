-- Common supervised pre-exec setup. Called only in the owned fork child.
local x=require('lua_repl_mcp.worker_posix')
local p=require('lua_repl_mcp.worker_protocol')
local M={}
function M.setup(output,g,options,limits)
 local function send(kind,extra)
  return x.write_all(output,assert(p.encode(p.record(kind,g,extra),limits)))
 end
 local reason='cwd_setup_failed'
 local ok,msg=pcall(function()
  if options.cwd then assert(x.u.chdir(options.cwd)) end
  local cwd=assert(x.u.getcwd())
  reason='stdio_setup_failed'
  local function redirect(path,flags,target,report)
   local fd,message=x.f.open(path,flags,tonumber('600',8)); assert(fd,message)
   if report then
    local absolute=path:sub(1,1)=='/' and path or cwd..'/'..path
    assert(send('file_created',{path=absolute}))
   end
   assert(x.u.dup2(fd,target))
   if fd~=target then x.u.close(fd) end
  end
  redirect(options.stdout_path or '/dev/null',options.stdout_path and (x.f.O_WRONLY|x.f.O_CREAT|x.f.O_EXCL) or x.f.O_WRONLY,1,options.stdout_path)
  if options.stderr_path and options.stderr_path==options.stdout_path then
   assert(x.u.dup2(1,2))
  else
   redirect(options.stderr_path or '/dev/null',options.stderr_path and (x.f.O_WRONLY|x.f.O_CREAT|x.f.O_EXCL) or x.f.O_WRONLY,2,options.stderr_path)
  end
  redirect(options.stdin_path or '/dev/null',x.f.O_RDONLY,0,false)
 end)
 if not ok then send('startup_error',{reason=reason,message=tostring(msg)}); return nil end
 return true
end
return M
