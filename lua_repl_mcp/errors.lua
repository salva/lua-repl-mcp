local M = {}
local notice = 'Original diagnostic data was not fully preserved.'
M.notice = notice
-- Preserve valid Unicode sequences; render each invalid byte as literal \xHH.
local function clean(s)
  local out, altered, i = {}, false, 1
  while i<=#s do
    local b=s:byte(i)
    local len=b<128 and 1 or (b>=194 and b<=223 and 2 or (b>=224 and b<=239 and 3 or (b>=240 and b<=244 and 4 or 0)))
    local part=len>0 and s:sub(i,i+len-1) or ''
    if len>0 and #part==len and utf8.len(part)==1 then out[#out+1]=part; i=i+len
    else out[#out+1]=string.format('\\x%02X',b); altered=true; i=i+1 end
  end
  return table.concat(out),altered
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
  local m,a=clean(safe(message))
  local trace,b=clean(result.traceback or '')
  local trunc=#m+#trace>limit
  if a or b or trunc then
    local budget=limit-#notice
    local original=m
    m=prefix(original,budget)
    budget=budget-#m
    trace=prefix(trace,budget)
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
