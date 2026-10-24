-- Private managed protocol in the invoking host state. All I/O is borrowed.
local p=require('lua_repl_mcp.worker_protocol')
local evaluator=require('lua_repl_mcp.evaluator')
local M={}
function M.serve(io,options)
 local function finish(reason,diagnostics) return {reason=reason,diagnostics=diagnostics} end
 local transport=false
 local ok,outcome=pcall(function()
  assert(type(io)=='table','invalid adapter')
  for _,k in ipairs({'read','write','flush'}) do assert(type(io[k])=='function','missing adapter '..k) end
  assert(type(options)=='table','missing options')
  local g=options.allocation_generation
  assert(math.type(g)=='integer' and g>0,'invalid allocation generation')
  assert(type(options.cwd)=='string' and options.cwd:sub(1,1)=='/','cwd must be absolute')
  assert(options.stopping==nil or type(options.stopping)=='function','invalid stopping callback')
  local limits=require('lua_repl_mcp.limits').connection(options.limits)
  local frames=require('lua_repl_mcp.framing').new(limits.worker_bytes)
  local function stopping() return options.stopping and options.stopping() end
  local function send(kind,extra)
   local text=assert(p.encode(p.record(kind,g,extra),limits))
   local pos=1
   transport=true
   while pos<=#text do
    local tail=text:sub(pos,pos+65535)
    local n,e=io.write(tail)
    if math.type(n)~='integer' or n<=0 or n>#tail then return nil,e or 'invalid write progress' end
    pos=pos+n
   end
   local flushed,e=io.flush()
   transport=false
   if flushed~=true then return nil,e or 'flush failed' end
   return true
  end
  if stopping() then return finish('host_stopping') end
  local sent,e=send('ready',{cwd=options.cwd})
  if not sent then return finish('transport_error',e) end
  local last=0
  while true do
   if stopping() then return finish('host_stopping') end
   local frame,err=frames:pop()
   if err then return finish('protocol_error',err) end
   if frame then
    local v=p.decode(frame,limits)
    if not v or v.allocation_generation~=g then return finish('protocol_error','invalid allocation record') end
    if v.type=='close' then return finish('closed') end
    if v.type~='execute' or v.execution_generation~=last+1 then return finish('protocol_error','invalid execution generation') end
    local input=p.execution_input(v,limits)
    if not input then return finish('protocol_error','invalid execution input') end
    if stopping() then return finish('host_stopping') end
    last=v.execution_generation
    local result=evaluator.execute(input,{max_bytes=limits.values_bytes,max_depth=limits.max_depth,diagnostic_bytes=limits.diagnostic_bytes},math.huge)
    local written,problem=send('result',{execution_generation=last,result=result})
    if not written then return finish('transport_error',problem) end
    if stopping() then return finish('host_stopping') end
   else
    transport=true
    local n=math.min(65536,frames.limit-frames.bytes+1)
    local data,problem=io.read(n)
    transport=false
    if data==nil then return finish(problem and 'transport_error' or 'eof',problem) end
    if type(data)~='string' or #data==0 or #data>n then return finish('transport_error','invalid read progress') end
    if not frames:feed(data) then return finish('protocol_error','frame exceeds limit') end
   end
  end
 end)
 if ok then return outcome end
 return finish(transport and 'transport_error' or 'protocol_error',tostring(outcome))
end
return M
