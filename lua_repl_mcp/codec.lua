-- Strict pure-Lua JSON boundary. Shape metadata belongs to decoded wire data,
-- not user tables; empty user tables always encode as objects.
local null = require('lua_repl_mcp').null
local M = {}
local shapes = setmetatable({}, {__mode='k'})
-- Validated private text and decoded snapshot: derivations clone the snapshot
-- rather than repeatedly parsing the same numeric tokens. Neither representation
-- is exposed to callers; original wire bytes remain the sole encode form.
-- Not a string value and never a user-table/metatable convention.
local encoded_data=setmetatable({}, {__mode='k'})
function M.json_data(text,options)
 local v,e=M.decode(text,options); if v==nil then return nil,e end
 local token={}; encoded_data[token]={text=text,value=v,depth=(options and options.max_depth) or 128}; return token
end
function M.json_value(token,checkpoint)
 local v=encoded_data[token]
 if v then return M.clone(v.value,{max_bytes=math.huge,max_depth=v.depth,checkpoint=checkpoint}) end
end
function M.json_bytes(token) local v=encoded_data[token]; return v and #v.text end
local safe = 9007199254740991
local function fail(reason, path) error({reason=reason, path=path or ''}, 0) end
local function utf8valid(s) return utf8.len(s) ~= nil end
local function ptr(path, key)
  -- A binary key cannot be named by a JSON Pointer. Identify its containing
  -- object instead; never leak invalid bytes into an otherwise safe error.
  if type(key) == 'string' and not utf8valid(key) then return path end
  return path .. '/' .. tostring(key):gsub('~','~0'):gsub('/','~1')
end
M.pointer = ptr
function M.kind(v) return shapes[v] end
function M.array(t) shapes[t] = 'array'; return t end
function M.object(t) shapes[t] = 'object'; return t end
M.valid_utf8 = utf8valid
local function number(n, path)
  if n ~= n or n == math.huge or n == -math.huge then fail('non-finite number',path) end
  if n % 1 == 0 and (n > safe or n < -safe) then fail('integer outside safe range',path) end
  return n
end
-- Inspect exact decimal digits BEFORE tonumber. Exponents are saturated, not
-- expanded; neither a huge token nor a huge exponent creates huge zero strings.
local function token_number(token, path)
  -- A finite nonintegral conversion cannot hide an out-of-range mathematical
  -- integer: those magnitudes have integral binary64 spacing. Keep the exact
  -- decimal inspection below for every integral conversion (including rounding
  -- onto a safe boundary), underflow, overflow and zero.
  local converted=tonumber(token)
  if converted and converted%1~=0 and converted~=math.huge and converted~=-math.huge and converted==converted then
    return converted
  end
  local mant, exp = token:match('^(.-)[eE]([+-]?%d+)$')
  mant = mant or token
  local e = 0
  if exp then
    local sign = exp:sub(1,1) == '-' and -1 or 1
    local digits = exp:gsub('^[+-]',''):gsub('^0+','')
    e = sign * (#digits > 7 and 10000000 or (tonumber(digits) or 0))
  end
  mant = mant:gsub('^-','')
  local frac = mant:match('%.(%d+)$') or ''
  local digits = mant:gsub('%.',''):gsub('^0+','')
  local shift = e - #frac
  if digits ~= '' then
    local trailing = #(digits:match('0*$'))
    if shift >= 0 or trailing >= -shift then
      local length = #digits + shift
      if length > 16 then fail('integer outside safe range',path) end
      if length == 16 then
        local whole = shift >= 0 and (digits .. string.rep('0',shift)) or digits:sub(1,length)
        if whole > '9007199254740991' then fail('integer outside safe range',path) end
      end
    end
  end
  local n = tonumber(token)
  if not n then fail('invalid number',path) end
  return number(n,path)
end
local function quote(s, path)
  if not utf8valid(s) then fail('invalid UTF-8',path) end
  return '"' .. s:gsub('[%z\1-\31\\"]', function(c)
    if c == '"' then return '\\"' elseif c == '\\' then return '\\\\' end
    return string.format('\\u%04x',c:byte())
  end) .. '"'
end
function M.encode(value, options)
  options = options or {}
  local maxdepth, maxbytes = options.max_depth or 128, options.max_bytes or 16*1024*1024
  local out, bytes, active = {}, 0, {}
  local work=0
  local function progress(n)
    if not options.checkpoint then return end
    work=work+(n or 1)
    if work>=65536 then work=0; options.checkpoint() end
  end
  local function put(s,path)
    bytes = bytes + #s
    if bytes > maxbytes then fail('encoded size limit exceeded',path) end
    out[#out+1] = s
  end
  local function emit_string(s,path)
    if not options.checkpoint then put(quote(s,path),path); return end
    if not utf8valid(s) then fail('invalid UTF-8',path) end
    put('"',path)
    -- Escape byte chunks (UTF-8 validity was checked for the complete string).
    -- Splitting a multibyte sequence here cannot alter its emitted bytes.
    for i=1,#s,65536 do
      local part=s:sub(i,i+65535):gsub('[%z\1-\31\\"]',function(ch)
        if ch=='"' then return '\\"' elseif ch=='\\' then return '\\\\' end
        return string.format('\\u%04x',ch:byte())
      end)
      put(part,path); progress(math.min(65536,#s-i+1))
    end
    put('"',path)
  end
  local visit
  visit = function(v,path,depth)
    progress()
    if encoded_data[v] then put(encoded_data[v].text,path); return end
    if rawequal(v,null) or v == nil then put('null',path); return end
    local t = type(v)
    if t == 'boolean' then put(v and 'true' or 'false',path)
    elseif t == 'string' then emit_string(v,path)
    elseif t == 'number' then
      number(v,path)
      -- Only the codec's output is normalized; never mutate the host locale.
      local text=math.type(v) == 'integer' and tostring(v) or string.format('%.17g',v)
      put((text:gsub(',', '.')),path)
    elseif t == 'table' then
      if depth > maxdepth then fail('nesting limit exceeded',path) end
      if active[v] then fail('cycle',path) end
      active[v] = true
      local count, highest, strings, nums = 0, 0, false, false
      for k in next,v do
        progress()
        count = count+1
        if type(k) == 'string' then strings=true
        elseif type(k) == 'number' and k % 1 == 0 and k >= 1 then nums=true; highest=math.max(highest,k)
        else fail('unsupported table key',path) end
      end
      if strings and nums then fail('mixed table keys',path) end
      if nums and highest ~= count then fail('array hole',path) end
      local array = nums or (count == 0 and shapes[v] == 'array' and not options.user_tables)
      put(array and '[' or '{',path)
      if array then
        for i=1,count do
          if i>1 then put(',',path) end
          visit(rawget(v,i),ptr(path,i-1),depth+1)
        end
      else
        -- Stable ordering makes evidence reproducible; never call __pairs.
        local keys = {}; for k in next,v do progress(); keys[#keys+1]=k end; table.sort(keys)
        for i,k in ipairs(keys) do
          if i>1 then put(',',path) end
          emit_string(k,ptr(path,k)); put(':',path)
          visit(rawget(v,k),ptr(path,k),depth+1)
        end
      end
      put(array and ']' or '}',path); active[v]=nil
    else fail('unsupported '..t,path) end
  end
  local ok, err = pcall(visit,value,options.path or '',1)
  if not ok then return nil,err end
  return table.concat(out)
end
function M.decode(text, options)
  options=options or {}
  local i,n = 1,#text
  -- Native bulk readers may suspend this otherwise blocking strict parser.
  -- The public handler supplies no checkpoint and remains purely blocking.
  local checkpoint=options.checkpoint
  local next_check=65536
  local function progress()
    if checkpoint and i>=next_check then next_check=i+65536; checkpoint() end
  end
  local function ws()
    if not checkpoint then local _,j=text:find('^[ \t\r\n]*',i); i=(j or i-1)+1; return end
    while i<=n do
      progress()
      local b=text:byte(i)
      if b~=32 and b~=9 and b~=13 and b~=10 then break end
      i=i+1; progress()
      b=text:byte(i)
      if b~=32 and b~=9 and b~=13 and b~=10 then break end
      -- Scan a bounded byte slice in C, retaining cooperative checkpoints even
      -- for a maximum request's legal trailing whitespace.
      local last=math.min(n,i+65535)
      local first=text:sub(i,last):find('[^ \t\r\n]')
      if first then i=i+first-1; progress(); return end
      i=last+1; progress()
    end
  end
  local function bad(reason,path) fail(reason .. ' at byte ' .. i,path) end
  local function str(path)
    i=i+1; local parts={}; local start=i
    while i<=n do
      progress()
      local b=text:byte(i)
      if b==34 then
        parts[#parts+1]=text:sub(start,i-1); i=i+1
        local s=table.concat(parts); if not utf8valid(s) then bad('invalid UTF-8',path) end
        return s
      elseif b==92 then
        parts[#parts+1]=text:sub(start,i-1); i=i+1
        local c=text:sub(i,i); local escapes={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
        if escapes[c] then parts[#parts+1]=escapes[c]; i=i+1
        elseif c=='u' then
          local hex=text:sub(i+1,i+4)
          if #hex~=4 or not hex:match('^%x+$') then bad('invalid Unicode escape',path) end
          local cp=tonumber(hex,16); i=i+5
          if cp>=0xd800 and cp<=0xdbff then
            local low=text:sub(i,i+5):match('^\\u(%x%x%x%x)')
            low=low and tonumber(low,16)
            if not low or low<0xdc00 or low>0xdfff then bad('unpaired surrogate',path) end
            cp=0x10000+(cp-0xd800)*1024+low-0xdc00; i=i+6
          elseif cp>=0xdc00 and cp<=0xdfff then bad('unpaired surrogate',path) end
          parts[#parts+1]=utf8.char(cp)
        else bad('invalid escape',path) end
        start=i
      elseif b<32 then bad('unescaped control byte',path)
      else i=i+1 end
    end
    bad('unterminated string',path)
  end
  local parse,parse_value
  parse_value=function(path,depth)
    ws(); local c=text:sub(i,i)
    if c=='"' then return str(path)
    elseif c=='[' or c=='{' then
      if depth>(options.max_depth or 128) then bad('nesting limit exceeded',path) end
      local array=c=='['; local close=array and ']' or '}'
      local result=array and M.array({}) or M.object({}); i=i+1; ws()
      if text:sub(i,i)==close then i=i+1; return result end
      local index=1
      while true do
        local key=index
        if not array then
          if text:sub(i,i)~='"' then bad('expected object key',path) end
          key=str(path); ws()
          if text:sub(i,i)~=':' then bad('expected colon',path) end
          i=i+1
          if rawget(result,key)~=nil then bad('duplicate object key',ptr(path,key)) end
        end
        result[key]=parse(ptr(path,array and index-1 or key),depth+1); index=index+1; ws()
        c=text:sub(i,i); i=i+1
        if c==close then return result end
        if c~=',' then bad('expected comma',path) end
        ws()
      end
    elseif c=='t' and text:sub(i,i+3)=='true' then i=i+4; return true
    elseif c=='f' and text:sub(i,i+4)=='false' then i=i+5; return false
    elseif c=='n' and text:sub(i,i+3)=='null' then i=i+4; return null
    else
      local start=i
      if c=='-' then i=i+1 end
      local b=text:byte(i)
      local function digit() local d=text:byte(i); return d and d>=48 and d<=57 end
      if b==48 then i=i+1
      elseif b and b>=49 and b<=57 then
        repeat i=i+1; progress() until not digit()
      else bad('expected value',path) end
      if text:byte(i)==46 then
        i=i+1; if not digit() then bad('expected fraction',path) end
        repeat i=i+1; progress() until not digit()
      end
      b=text:byte(i)
      if b==101 or b==69 then
        i=i+1; b=text:byte(i); if b==43 or b==45 then i=i+1 end
        if not digit() then bad('expected exponent',path) end
        repeat i=i+1; progress() until not digit()
      end
      return token_number(text:sub(start,i-1),path)
    end
  end
  parse=function(path,depth)
    ws(); progress(); local start=i
    local v=parse_value(path,depth)
    if options.json_path and path==options.json_path then
     local token={}; encoded_data[token]={text=text:sub(start,i-1),value=v,depth=options.max_depth or 128}; return token
    end
    return v
  end
  local ok,result=pcall(function()
    if n>(options.max_bytes or 16*1024*1024) then fail('input size limit exceeded','') end
    local v=parse('',1); ws(); if i<=n then bad('trailing data','') end; return v
  end)
  if not ok then return nil,result end
  return result
end
-- Fresh raw JSON data copy. Never consult/copy user metatables, and never
-- expand admitted strings/numbers through an encode/decode round trip.
-- The byte counter is the canonical JSON size for library-originated data.
function M.clone(value,options)
  options=options or {}
  local active,bytes={},0
  local work=0
  local function progress(n)
    if not options.checkpoint then return end
    work=work+(n or 1)
    if work>=65536 then work=0; options.checkpoint() end
  end
  local maxdepth,maxbytes=options.max_depth or 128,options.max_bytes or 16*1024*1024
  local function add(n,path)
    if n>maxbytes-bytes then fail('encoded size limit exceeded',path) end
    bytes=bytes+n
  end
  local function stringbytes(s,path)
    if not utf8valid(s) then fail('invalid UTF-8',path) end
    local n=2+#s
    for i=1,#s do
      progress()
      local b=s:byte(i)
      if b<32 then n=n+5 elseif b==34 or b==92 then n=n+1 end
    end
    add(n,path)
  end
  local visit
  visit=function(v,path,depth)
    progress()
    if rawequal(v,null) or v==nil then add(4,path); return null end
    local t=type(v)
    if t=='string' then stringbytes(v,path); return v
    elseif t=='boolean' then add(v and 4 or 5,path); return v
    elseif t=='number' then
      number(v,path)
      -- Immutable wire-origin derivations have already charged original bytes;
      -- an explicitly unbounded copy needs validation, not numeric formatting.
      -- Finite library-origin budgets still charge canonical encoded size.
      if maxbytes~=math.huge then
        local text=math.type(v)=='integer' and tostring(v) or string.format('%.17g',v)
        add(#text,path)
      end
      return v
    elseif t~='table' then fail('unsupported '..t,path) end
    if depth>maxdepth then fail('nesting limit exceeded',path) end
    if active[v] then fail('cycle',path) end
    active[v]=true
    local count,highest,strings,nums=0,0,false,false
    for k in next,v do
      progress()
      count=count+1
      if type(k)=='string' then strings=true
      elseif type(k)=='number' and k%1==0 and k>=1 then nums=true; highest=math.max(highest,k)
      else fail('unsupported table key',path) end
    end
    if strings and nums then fail('mixed table keys',path) end
    if nums and highest~=count then fail('array hole',path) end
    local array=nums or (count==0 and shapes[v]=='array' and not options.user_tables)
    local copy=array and M.array({}) or M.object({})
    add(2+math.max(0,count-1),path)
    for k,item in next,v do
      progress()
      local child=ptr(path,array and k-1 or k)
      if not array then stringbytes(k,child); add(1,child) end
      copy[k]=visit(item,child,depth+1)
    end
    active[v]=nil
    return copy
  end
  local ok,result=pcall(visit,value,options.path or '',1)
  if not ok then return nil,result end
  return result
end
return M
