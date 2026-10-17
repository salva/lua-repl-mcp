-- Private guardian transport. A bounded newline frame is retained per direction.
-- Only manager/guardian entrypoints import native dependencies.
local x=require('lua_repl_mcp.worker_posix')
local c=require('lua_repl_mcp.codec')
local M={}
function M.new(fd,limit)
 x.nonblock(fd); x.clo(fd,true)
 return {fd=fd,limit=limit,input='',output='',offset=1}
end
function M.enqueue(ch,value)
 local text,err=c.encode(value,{max_bytes=ch.limit,max_depth=160})
 if not text then error(err or 'guardian encoding failed') end
 assert(#ch.output==0,'guardian output backpressure')
 ch.output=text..'\n'; ch.offset=1
end
function M.flush(ch)
 if #ch.output==0 then return end
 local n,msg,err=x.u.write(ch.fd,ch.output:sub(ch.offset,ch.offset+65535))
 if n and n>0 then
  ch.offset=ch.offset+n
  if ch.offset>#ch.output then ch.output=''; ch.offset=1 end
 elseif not x.retryable(err) then error(msg or 'guardian write failed') end
end
function M.receive(ch,accept)
 local budget=65536
 while budget>0 do
  local s,msg,err=x.u.read(ch.fd,math.min(65536,budget))
  if not s then if x.retryable(err) then return end; error(msg) end
  if s=='' then return false end
  budget=budget-#s
  local rest=s
  repeat
   local nl=rest:find('\n',1,true)
   local part=nl and rest:sub(1,nl-1) or rest
   assert(#ch.input+#part<=ch.limit,'guardian frame bound')
   ch.input=ch.input..part
   if not nl then break end
   local value=assert(c.decode(ch.input,{max_depth=160})); ch.input=''
   accept(value)
   rest=rest:sub(nl+1)
  until rest==''
 end
 return true
end
return M
