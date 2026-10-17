-- Byte framing only: never decode trailing data during lifecycle handoff.
local M={}
function M.new(limit)
  local self={buffer='',limit=limit}
  function self:feed(bytes) self.buffer=self.buffer..bytes end
  function self:pop()
    local p=self.buffer:find('\n',1,true)
    if (p and p-1 or #self.buffer)>self.limit then return nil,'input frame limit exceeded' end
    if not p then return nil end
    local frame=self.buffer:sub(1,p-1)
    self.buffer=self.buffer:sub(p+1)
    return frame
  end
  function self:handoff()
    local messages={}
    local pos=1
    while true do
      local p=self.buffer:find('\n',pos,true)
      if not p then break end
      messages[#messages+1]=self.buffer:sub(pos,p-1); pos=p+1
    end
    return messages,self.buffer:sub(pos)
  end
  return self
end
return M
