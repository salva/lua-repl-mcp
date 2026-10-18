local M = {}
local notice = 'Original diagnostic data was not fully preserved.'
M.notice = notice
-- Preserve valid Unicode sequences; render each invalid byte as literal \xHH.
local function clean(s,limit)
  local out, altered, i, bytes = {}, false, 1, 0
  while i<=#s do
    local b=s:byte(i)
    local len=b<128 and 1 or (b>=194 and b<=223 and 2 or (b>=224 and b<=239 and 3 or (b>=240 and b<=244 and 4 or 0)))
    local part=len>0 and s:sub(i,i+len-1) or ''
    if len>0 and #part==len and utf8.len(part)==1 then i=i+len
    else part=string.format('\\x%02X',b); altered=true; i=i+1 end
    bytes=bytes+#part
    -- Keep only a prefix, but scan the rest for late invalid-byte flags and
    -- exact truncation accounting. No source-sized expanded buffer is built.
    if bytes<=limit then out[#out+1]=part end
  end
  return table.concat(out),altered,bytes
end
local function safe(value)
  local t=type(value)
  if t=='string' then return value end
  if t=='number' or t=='boolean' or t=='nil' then return tostring(value) end
  return '<'..t..' error value>'
end
M.describe = safe
local function prefix(s,n)
  if #s<=n then return s end
  s=s:sub(1,math.max(0,n))
  while not utf8.len(s) do s=s:sub(1,-2) end
  return s
end
function M.new(code, message, stage, state, extra, limit)
  limit=limit or 65536
  assert(math.type(limit)=='integer' and limit>=#notice, 'diagnostic limit too small')
  local result={code=code,stage=stage,execution_state=state}
  if extra then for k,v in next,extra do result[k]=v end end
  -- Optional pointers must never crowd out required error/effect metadata.
  -- Six bytes per source byte covers worst-case JSON escaping; no ancestor
  -- search or truncated (and hence false) pointer is emitted.
  if result.path and #result.path>math.floor(65536/6) then result.path=nil end
  local m,a,mb=clean(safe(message),limit)
  local trace,b,tb=clean(result.traceback or '',limit)
  local trunc=mb+tb>limit
  if a or b or trunc then
    local budget=limit-#notice
    local original_bytes=mb+tb
    m=prefix(m,budget)
    budget=budget-#m
    trace=prefix(trace,budget)
    -- Reserving the loss notice can itself discard diagnostic text, even
    -- when the escaped source fitted the original limit. Account for both
    -- fields after UTF-8-safe clipping, before appending the notice.
    trunc=#m+#trace<original_bytes
    -- Notice is part of the combined bounded message/traceback.
    m=m..notice
    result.data_preserved=false
    result.invalid_bytes_escaped=(a or b) or nil
    result.truncated=trunc or nil
  end
  result.message=m
  result.traceback=trace~='' and trace or nil
  return result
end
function M.failure(err) return {status='failed',error=err} end
return M
