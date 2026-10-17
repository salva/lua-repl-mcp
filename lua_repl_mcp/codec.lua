-- Strict pure-Lua JSON boundary. Shape metadata belongs to decoded wire data,
-- not user tables; empty user tables always encode as objects.
local null = require('lua_repl_mcp').null
local M = {}
local shapes = setmetatable({}, {__mode='k'})
-- Private immutable encoded JSON data, created only after strict decoding.
-- Not a string value and never a user-table/metatable convention.
local encoded_data=setmetatable({}, {__mode='k'})
function M.json_data(text,options)
 local v,e=M.decode(text,options); if v==nil then return nil,e end
 local token={}; encoded_data[token]={text=text,depth=(options and options.max_depth) or 128}; return token
end
function M.json_value(token)
 local v=encoded_data[token]
 if v then return M.decode(v.text,{max_bytes=#v.text,max_depth=v.depth}) end
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
  local function put(s,path)
    bytes = bytes + #s
    if bytes > maxbytes then fail('encoded size limit exceeded',path) end
    out[#out+1] = s
  end
  local visit
  visit = function(v,path,depth)
    if encoded_data[v] then put(encoded_data[v].text,path); return end
    if rawequal(v,null) or v == nil then put('null',path); return end
    local t = type(v)
    if t == 'boolean' then put(v and 'true' or 'false',path)
    elseif t == 'string' then put(quote(v,path),path)
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
        local keys = {}; for k in next,v do keys[#keys+1]=k end; table.sort(keys)
        for i,k in ipairs(keys) do
          if i>1 then put(',',path) end
          put(quote(k,ptr(path,k)) .. ':',path)
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
  local function ws() local _,j=text:find('^[ \t\r\n]*',i); i=(j or i-1)+1 end
  local function bad(reason,path) fail(reason .. ' at byte ' .. i,path) end
  local function str(path)
    i=i+1; local parts={}; local start=i
    while i<=n do
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
            local low=text:sub(i):match('^\\u(%x%x%x%x)')
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
      c=text:sub(i,i)
      if c=='0' then i=i+1
      elseif c:match('[1-9]') and c~='' then
        repeat i=i+1 until not text:sub(i,i):match('%d')
      else bad('expected value',path) end
      if text:sub(i,i)=='.' then
        i=i+1; if not text:sub(i,i):match('%d') then bad('expected fraction',path) end
        repeat i=i+1 until not text:sub(i,i):match('%d')
      end
      c=text:sub(i,i)
      if c=='e' or c=='E' then
        i=i+1; c=text:sub(i,i); if c=='+' or c=='-' then i=i+1 end
        if not text:sub(i,i):match('%d') then bad('expected exponent',path) end
        repeat i=i+1 until not text:sub(i,i):match('%d')
      end
      return token_number(text:sub(start,i-1),path)
    end
  end
  parse=function(path,depth)
    ws(); local start=i
    local v=parse_value(path,depth)
    if options.json_path and path==options.json_path then
     local token={}; encoded_data[token]={text=text:sub(start,i-1),depth=options.max_depth or 128}; return token
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
  local maxdepth,maxbytes=options.max_depth or 128,options.max_bytes or 16*1024*1024
  local function add(n,path)
    if n>maxbytes-bytes then fail('encoded size limit exceeded',path) end
    bytes=bytes+n
  end
  local function stringbytes(s,path)
    if not utf8valid(s) then fail('invalid UTF-8',path) end
    local n=2+#s
    for i=1,#s do
      local b=s:byte(i)
      if b<32 then n=n+5 elseif b==34 or b==92 then n=n+1 end
    end
    add(n,path)
  end
  local visit
  visit=function(v,path,depth)
    if rawequal(v,null) or v==nil then add(4,path); return null end
    local t=type(v)
    if t=='string' then stringbytes(v,path); return v
    elseif t=='boolean' then add(v and 4 or 5,path); return v
    elseif t=='number' then
      number(v,path)
      local text=math.type(v)=='integer' and tostring(v) or string.format('%.17g',v)
      add(#text,path); return v
    elseif t~='table' then fail('unsupported '..t,path) end
    if depth>maxdepth then fail('nesting limit exceeded',path) end
    if active[v] then fail('cycle',path) end
    active[v]=true
    local count,highest,strings,nums=0,0,false,false
    for k in next,v do
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
