-- Manager attachment to nonblocking streams; lifecycle uses the shared core.
local codec=require('lua_repl_mcp.codec')
local protocol=require('lua_repl_mcp.protocol')
local M={}
function M.serve(io,options)
 local manager,transport
 local ok,err=pcall(function()
 manager=require('lua_repl_mcp.manager').new(options)
 transport=require('lua_repl_mcp.client_transport').new(manager,io)
 local core=protocol.new{
  max_depth=manager.limits.max_depth,input_bytes=manager.limits.input_bytes,
  tools=assert(codec.decode(require('lua_repl_mcp.manager_schemas'))),
  names={session_create=true,session_execute=true,session_wait=true,session_kill=true,session_list=true},
  instructions='Trusted Lua code runs in separate persistent workers. Use explicit return; no automatic output capture. Terminal results are single-consumer. Wait deadlines do not kill; hard execution deadlines and request cancellation destroy the session.',
  submit=function(id,name,args,original) transport:submit(id,name,args,original) end,
  outstanding=function(id) return transport:outstanding(id) end,
  notification=function(r)
   if r.method=='notifications/cancelled' and type(r.params)=='table' then
    local id=r.params.requestId
    if type(id)=='string' or type(id)=='number' then transport:cancel(id) end
   end
  end,
 }
 -- One complete frame owns strict decoding. Preserve wire dispatch order and
 -- bounded retention; worker timers/output still progress between parser slices.
 local decoding
 local function progress()
  if not decoding then return true end
  local pass,response=coroutine.resume(decoding)
  if not pass then error(response,0) end
  if coroutine.status(decoding)~='dead' then return false end
  decoding=nil
  if response then
   local encoded=codec.encode(response,{max_bytes=transport.response_bytes,max_depth=transport.encode_depth})
   if encoded then transport:enqueue(encoded) else transport:close('protocol response bound') end
  end
  return true
 end
 local function frame(text)
  if io.stopping and io.stopping() then return end
  decoding=coroutine.create(function() return core:handle(text,coroutine.yield) end)
  return progress()
 end
  while not (io.stopping and io.stopping()) and transport:step(frame,progress) do
   if io.pause then io.pause() end
  end
 end)
 local cleaned,cleanup_error=pcall(function()
  if transport then transport:close(ok and 'eof' or 'server error')
  elseif manager then manager:disconnect() end
 end)
 if not cleaned and ok then error(cleanup_error,0) end
 if not ok then error(err,0) end
 return transport and transport.closed
end
function M.main(argv)
 local options={}
 argv=argv or {}
 local i=1
 while i<=#argv do
  assert(argv[i]=='--startup-timeout-ms' and argv[i+1] and argv[i+1]:match('^[0-9]+$'),'usage: lua-repl-mcp [--startup-timeout-ms N]')
  local n=tonumber(argv[i+1])
  assert(math.type(n)=='integer' and n>=1 and n<=2147483647,'invalid startup timeout')
  options.startup_timeout_ms=n; i=i+2
 end
 local x=require('lua_repl_mcp.worker_posix')
 local requested
 x.s.signal(x.s.SIGPIPE,x.s.SIG_IGN)
 x.s.signal(x.s.SIGINT,function(sig) requested=requested or sig end)
 x.s.signal(x.s.SIGTERM,function(sig) requested=requested or sig end)
 local function read(n)
  local data,msg,errno=x.u.read(0,n)
  if data=='' then return nil,'eof' end
  if not data and x.retryable(errno) then return nil,'again' end
  return data,msg
 end
 local function write(s)
  local n,msg,errno=x.u.write(1,s)
  if not n and x.retryable(errno) then return nil,'again' end
  return n,msg
 end
 local backend
 local ok,err=pcall(function()
 x.nonblock(0); x.nonblock(1)
 backend=require('lua_repl_mcp.guardian').new(options)
 M.serve({read=read,write=write,stopping=function() return requested end,pause=function()
  -- A short bounded poll avoids spinning while workers progress independently.
  x.p.poll({[0]={events={IN=true}}},5)
 end},{supervisor=backend})
 end)
 local clean,why=pcall(function() if backend then backend:shutdown() end end)
 if not ok then x.u.write(2,tostring(err)..'\n') end
 if not clean then x.u.write(2,tostring(why)..'\n') end
 os.exit(requested and 128+requested or ((ok and clean) and 0 or 1))
end
return M
