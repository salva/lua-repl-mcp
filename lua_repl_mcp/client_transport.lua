-- Connection-owned bounded nonblocking transport. U8 may feed decoded RPCs to
-- submit(); read callback handles protocol lifecycle/discovery. No native imports.
local protocol=require('lua_repl_mcp.protocol')
local framing=require('lua_repl_mcp.framing')
local M={}; local C={}; C.__index=C
function M.new(manager,io,o)
 o=o or {}
 assert(type(o)=='table','transport options must be a table')
 local source=manager.limits or {}
 local bounds={input_bytes=source.input_bytes or 16*1048576,response_bytes=source.response_bytes or 128*1048576,output_bytes=source.output_bytes or 256*1048576}
 for k,v in pairs(o) do
  assert(bounds[k]~=nil,'unknown transport option')
  assert(math.type(v)=='integer' and v>0 and v<=2147483647,'invalid transport bound')
  bounds[k]=v
 end
 -- Explicit adapter overrides must still be able to echo every legal input ID
 -- in the bounded fallback. A manager-configured connection cannot be split
 -- into independently inconsistent encoder and transport budgets.
 if manager.limit_options and next(manager.limit_options) then
  for k,v in pairs(o) do assert(v==source[k],'transport conflicts with manager limits') end
 end
 if o.input_bytes~=nil then
  assert(bounds.response_bytes>=bounds.input_bytes+1024,'response cannot echo legal input ID')
 end
 local self=setmetatable({manager=manager,io=io,input=framing.new(bounds.input_bytes),
  encode_depth=source.max_depth and source.max_depth+4 or 132,response_bytes=bounds.response_bytes,output_bytes=bounds.output_bytes,
  queue={},pending={},bytes=0,high_water=0,input_high_water=0,closed=false},C)
 assert(self.output_bytes>=self.response_bytes+1,'output must hold a response plus newline')
 return self
end
function C:close(reason)
 if not self.closed then
  self.closed=reason or 'disconnect'; self.queue={}; self.pending={}; self.bytes=0
  -- Enqueue can fail inside a manager commit callback. Stop transport now but
  -- defer manager teardown until the callback releases its non-reentry guard.
  if self.manager.committing then self.cleanup_pending=true
  else self.manager:disconnect() end
 end
end
function C:enqueue(text)
 if self.closed then return false end
 text=text..'\n'
 if self.bytes+#text>self.output_bytes then self:close('output bound'); return false end
 self.queue[#self.queue+1]={text=text,offset=1}
 self.bytes=self.bytes+#text; self.high_water=math.max(self.high_water,self.bytes)
 return true
end
function C:submit(id,tool,args,original)
 if self.closed then return end
 if self.manager.requests[id] then
  local text=require('lua_repl_mcp.codec').encode(protocol.error(nil,-32600,'Duplicate outstanding request ID'))
  return self:enqueue(text)
 end
 -- Cancelled handles no longer own slots. Remove them before admitting another
 -- handle even when the caller submits/cancels repeatedly without a tick.
 local live={}
 for _,p in ipairs(self.pending) do
  if not p.request.cancelled and not p.request.done then live[#live+1]=p end
 end
 self.pending=live
 local r=self.manager:accept(tool,args,id,original)
 if r.admission_rejected then
  -- No slot means no pending-handle ownership. Charge the rejection to encoded
  -- output immediately; a stopped reader eventually trips the output bound.
  local text=protocol.encode_result(id,assert(self.manager:preview(r)),
   {max_bytes=self.response_bytes,max_depth=self.encode_depth},r.tool)
  if not text then self:close('response bound'); return false end
  return self:enqueue(text)
 end
 self.pending[#self.pending+1]={id=id,request=r}
end
function C:cancel(id) return self.manager:cancel(id) end
function C:step(on_frame)
 if self.closed then return false end
 -- Each direction is bounded per tick, independently of request saturation.
 -- Always advance worker timers before processing more client traffic.
 self.manager:step(0)
 local chunk,err
 -- Drain buffered complete frames before asking the adapter for more. Otherwise
 -- a flood of short frames could grow a backlog faster than the tick quota.
 if self.input.buffer:find('\n',1,true) then err='again'
 else chunk,err=self.io.read(math.min(65536,self.input.limit-#self.input.buffer+1)) end
 if chunk then
  if #chunk==0 or #chunk>65536 then self:close('invalid read'); return false end
  local ok=self.input:feed(chunk)
  self.input_high_water=math.max(self.input_high_water,#self.input.buffer)
  if not ok then self:close('input bound'); return false end
 elseif err~='again' then self:close(err or 'eof'); return false end
 for _=1,16 do
  local frame,e=self.input:pop()
  if e then self:close(e); return false end
  if not frame then break end
  on_frame(frame,self)
  if self.closed then return false end
 end
 local rest={}
 for _,p in ipairs(self.pending) do
  local r=p.request
  if not r.cancelled then
   local v=self.manager:preview(r)
   if v then
    local text,original=protocol.encode_result(p.id,v,
     {max_bytes=self.response_bytes,max_depth=self.encode_depth},r.tool)
    if not text then self:close('response bound'); return false end
    if original then
     local committed=self.manager:commit(r,function(current)
      -- Recheck at the owning commit boundary, never enqueue stale preview.
      local encoded,full=protocol.encode_result(p.id,current,
       {max_bytes=self.response_bytes,max_depth=self.encode_depth},r.tool)
      return full and self:enqueue(encoded)
     end)
     if self.cleanup_pending then
      self.cleanup_pending=nil; self.manager:disconnect()
     end
     if not committed and not self.closed then rest[#rest+1]=p end
    else
     -- Small replacement is sent without consuming a retained terminal result.
     if not self:enqueue(text) then return false end
     r.cancelled=true; self.manager:release(r)
     if r.request_id~=nil then self.manager.requests[r.request_id]=nil end
    end
   else rest[#rest+1]=p end
  end
  if self.closed then return false end
 end
 self.pending=rest
 local budget=65536
 while budget>0 and self.queue[1] do
  local item=self.queue[1]
  local data=item.text:sub(item.offset,item.offset+budget-1)
  local n,e=self.io.write(data)
  if not n then
   if e=='again' then break end
   self:close(e or 'write failure'); return false
  end
  if math.type(n)~='integer' or n<=0 or n>#data then self:close('invalid write'); return false end
  item.offset=item.offset+n; budget=budget-n
  if item.offset>#item.text then
   self.bytes=self.bytes-#item.text; table.remove(self.queue,1)
  end
 end
 return true
end
return M
