-- Default host owns descriptor/process lifetime; session.serve only borrows I/O.
local x=require('lua_repl_mcp.worker_posix')
local M={}
function M.run(input,output,g,options,limit_options)
 x.clo(input,true)
 if output~=input then x.clo(output,true) end
 -- Retain the internal direct-test wrapper; production setup is pre-exec.
 if options and not require('lua_repl_mcp.worker_setup').setup(output,g,options,require('lua_repl_mcp.limits').connection(limit_options)) then return end
 return require('lua_repl_mcp.session').serve({
  read=function(n)
   while true do
    local data,msg,err=x.u.read(input,n)
    if data then return data~='' and data or nil end
    if err~=x.e.EINTR then return nil,msg end
   end
  end,
  write=function(text)
   while true do
    local n,msg,err=x.u.write(output,text)
    if n or err~=x.e.EINTR then return n,msg end
   end
  end,
  flush=function() return true end,
 },{allocation_generation=g,limits=limit_options,cwd=assert(x.u.getcwd())})
end
function M.main()
 local ok=pcall(function()
  local b=assert(require('lua_repl_mcp.bootstrap').decode(os.getenv('LUA_REPL_MCP_SESSION_FD'),os.getenv('LUA_REPL_MCP_ALLOCATION_GENERATION'),os.getenv('LUA_REPL_MCP_LIMITS')))
  M.run(b.fd,b.fd,b.allocation_generation,nil,b.limits)
 end)
 x.u._exit(ok and 0 or 1)
end
return M
