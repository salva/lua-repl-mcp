-- Byte framing only: never decode trailing data during lifecycle handoff.
local M={}
function M.new(limit)
  local self={limit=limit,bytes=0,ready=0}
  local parts,partial={},0
  local frames,first,last={},1,0
  local function tail() return table.concat(parts) end
  local function snapshot()
    local out={}
    for i=first,last do out[#out+1]=frames[i]; out[#out+1]='\n' end
    out[#out+1]=tail()
    return table.concat(out)
  end
  -- Compatibility inspection only. Runtime owners use byte/ready counters;
  -- observing the old buffer must not force prefix copies on every IO turn.
  setmetatable(self,{__index=function(_,key) if key=='buffer' then return snapshot() end end})
  function self:feed(bytes)
    if self.overflow then return nil,'input frame limit exceeded' end
    local pos=1
    while pos<=#bytes do
      local p=bytes:find('\n',pos,true)
      local count=(p and p-1 or #bytes)-pos+1
      if partial+count>self.limit then
        -- One sentinel byte, no bytes beyond the first overflowing frame.
        local keep=self.limit-partial+1
        parts[#parts+1]=bytes:sub(pos,pos+keep-1)
        partial=partial+keep; self.bytes=self.bytes+keep
        self.overflow=true
        return nil,'input frame limit exceeded'
      end
      if count>0 then
        parts[#parts+1]=(pos==1 and count==#bytes) and bytes or bytes:sub(pos,pos+count-1)
        partial=partial+count; self.bytes=self.bytes+count
      end
      if not p then break end
      last=last+1; frames[last]=tail()
      parts={}; partial=0
      self.ready=self.ready+1; self.bytes=self.bytes+1
      pos=p+1
    end
    return true
  end
  function self:pop()
    if self.ready>0 then
      local frame=frames[first]; frames[first]=nil; first=first+1
      self.ready=self.ready-1; self.bytes=self.bytes-#frame-1
      if self.ready==0 then frames={}; first=1; last=0 end
      return frame
    end
    if self.overflow then return nil,'input frame limit exceeded' end
    return nil
  end
  function self:handoff()
    local messages={}
    for i=first,last do messages[#messages+1]=frames[i] end
    return messages,tail()
  end
  return self
end
return M
