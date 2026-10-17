-- Private guardian transport. A bounded newline frame is retained per direction.
-- Only manager/guardian entrypoints import native dependencies.
local x=require('lua_repl_mcp.worker_posix')
local c=require('lua_repl_mcp.codec')
local M={}
function M.new(fd,limit)
 x.nonblock(fd); x.clo(fd,true)
 return {fd=fd,limit=limit,input='',input_parts={},input_bytes=0,output='',offset=1}
end
-- A logical batch is streamed as one bounded item per frame. Retain references
-- to the bounded allocation/command snapshot, never an encoded aggregate.
function M.busy(ch) return ch.batch~=nil or ch.encoding~=nil or #ch.output>0 end
local function advance(ch)
 if not ch.batch then return end
 local i=ch.batch_index
 local last=i>=#ch.batch
 local value={items={},done=last}
 if ch.batch[i] then value.items[1]=ch.batch[i] end
 ch.encoding=coroutine.create(function()
  local text,err=c.encode(value,{max_bytes=ch.limit,max_depth=520,checkpoint=coroutine.yield})
  if not text then error(err or 'guardian encoding failed') end
  return text..'\n'
 end)
 if last then ch.batch=nil else ch.batch_index=i+1 end
end
function M.enqueue(ch,value)
 assert(not M.busy(ch),'guardian output backpressure')
 assert(type(value)=='table','guardian batch required')
 ch.batch=value; ch.batch_index=1
 advance(ch)
end
function M.flush(ch)
 if #ch.output==0 and not ch.encoding then advance(ch) end
 if ch.encoding then
  local ok,text=coroutine.resume(ch.encoding)
  assert(ok,text)
  if coroutine.status(ch.encoding)~='dead' then return end
  ch.encoding=nil; ch.output=text; ch.offset=1
 end
 if #ch.output==0 then return end
 local n,msg,err=x.u.write(ch.fd,ch.output:sub(ch.offset,ch.offset+65535))
 if n and n>0 then
  ch.offset=ch.offset+n
  if ch.offset>#ch.output then ch.output=''; ch.offset=1 end
 elseif not x.retryable(err) then error(msg or 'guardian write failed') end
end
function M.receive(ch,accept,paused)
 -- One parser slice per turn. Pending complete bytes remain private until
 -- strict decode finishes; caller can service control/liveness between slices.
 local function resume_validation()
  local ok,value=coroutine.resume(ch.validation)
  assert(ok,value)
  if coroutine.status(ch.validation)~='dead' then return false end
  ch.validation=nil
  assert(type(value)=='table' and type(value.items)=='table' and type(value.done)=='boolean','invalid guardian fragment')
  accept(value.items,value.done)
  return true
 end
 if ch.validation then
  if not resume_validation() then return true end
  if paused and paused() then return true end
 end
 local budget=65536
 while budget>0 do
  local s,msg,err
  if ch.rest then s=ch.rest; ch.rest=nil
  else s,msg,err=x.u.read(ch.fd,math.min(65536,budget)) end
  if not s then if x.retryable(err) then return end; error(msg) end
  if s=='' then return false end
  budget=budget-#s
  local rest=s
  repeat
   local nl=rest:find('\n',1,true)
   local part=nl and rest:sub(1,nl-1) or rest
   -- Retain each received chunk once; concatenate only for full validation.
   ch.input_parts=ch.input_parts or {}
   ch.input_bytes=(ch.input_bytes or 0)+#part
   assert(ch.input_bytes<=ch.limit,'guardian frame bound')
   ch.input_parts[#ch.input_parts+1]=part
   if not nl then break end
   local text=table.concat(ch.input_parts); ch.input_parts={}; ch.input_bytes=0
   ch.validation=coroutine.create(function()
    return assert(c.decode(text,{max_depth=520,max_bytes=ch.limit,json_path="/items/0/request",checkpoint=coroutine.yield}))
   end)
   rest=rest:sub(nl+1)
   if not resume_validation() or (paused and paused()) then if rest~='' then ch.rest=rest end; return true end
  until rest==''
 end
 return true
end
return M
