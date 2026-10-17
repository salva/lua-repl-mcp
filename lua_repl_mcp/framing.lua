-- Byte framing only: never decode trailing data during lifecycle handoff.
local M={}
function M.new(limit)
  local self={buffer='',limit=limit}
  -- Inspect incoming bytes before concatenation. Retain only the legal prefix
  -- plus one overflow sentinel, even when a caller supplies a huge chunk.
  -- Earlier complete frames remain readable; overflow is sticky at its frame.
  function self:feed(bytes)
    if self.overflow then return nil,'input frame limit exceeded' end
    -- Anchor the last-newline scan. An unanchored greedy pattern retries
    -- every suffix when a partial frame has no newline (quadratic work).
    local last=self.buffer:match('^.*()\n')
    local length=#self.buffer-(last or 0)
    local pos=1
    while pos<=#bytes do
      local p=bytes:find('\n',pos,true)
      local count=(p and p-1 or #bytes)-pos+1
      if length+count>self.limit then
        local keep=pos+self.limit-length
        self.buffer=self.buffer..bytes:sub(1,keep)
        self.overflow=true
        return nil,'input frame limit exceeded'
      end
      if not p then break end
      length=0; pos=p+1
    end
    self.buffer=self.buffer..bytes
    return true
  end
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
