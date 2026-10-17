-- Manager attachment to nonblocking streams; lifecycle uses the shared core.
local codec=require('lua_repl_mcp.codec')
local protocol=require('lua_repl_mcp.protocol')
local M={}
function M.serve(io,options)
 local manager=require('lua_repl_mcp.manager').new(options)
 local transport=require('lua_repl_mcp.client_transport').new(manager,io)
 local core=protocol.new{
  tools=assert(codec.decode(require('lua_repl_mcp.manager_schemas'))),
  names={session_create=true,session_execute=true,session_wait=true,session_kill=true,session_list=true},
  instructions='Trusted Lua code runs in separate persistent workers. Use explicit return; no automatic output capture. Terminal results are single-consumer. Wait deadlines do not kill; hard execution deadlines and request cancellation destroy the session.',
  submit=function(id,name,args) transport:submit(id,name,args) end,
  notification=function(r)
   if r.method=='notifications/cancelled' and type(r.params)=='table' then
    local id=r.params.requestId
    if type(id)=='string' or type(id)=='number' then transport:cancel(id) end
   end
  end,
 }
 local function frame(text)
  local response=core:handle(text)
  if response then
   local encoded=codec.encode(response,{max_bytes=transport.response_bytes,max_depth=transport.encode_depth})
   if encoded then transport:enqueue(encoded) else transport:close('protocol response bound') end
  end
 end
 local ok,err=pcall(function()
  while transport:step(frame) do
   if io.pause then io.pause() end
  end
 end)
 transport:close(ok and 'eof' or 'server error')
 if not ok then error(err,0) end
 return transport.closed
end
function M.main()
 local x=require('lua_repl_mcp.worker_posix')
 x.s.signal(x.s.SIGPIPE,x.s.SIG_IGN)
 x.nonblock(0); x.nonblock(1)
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
 return M.serve{read=read,write=write,pause=function()
  -- A short bounded poll avoids spinning while workers progress independently.
  x.p.poll({[0]={events={IN=true}}},5)
 end}
end
return M
