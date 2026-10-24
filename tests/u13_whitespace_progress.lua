-- Cooperative whitespace scanning must be bounded and lexically identical.
local c=require('lua_repl_mcp.codec')
for _,count in ipairs{0,1,2,65535,65536,65537,200000} do
 local space=string.rep(' ',count)
 for _,text in ipairs{space..'[1e-7, 2]'..space,space..'{"a":true}'..space} do
  local turns=0
  local value=assert(c.decode(text,{max_bytes=#text,checkpoint=function() turns=turns+1 end}))
  local plain=assert(c.decode(text,{max_bytes=#text}))
  assert(c.encode(value)==c.encode(plain))
  if #text>65536 then assert(turns>0) end
 end
 local bad=space..'1 '..string.char(11)
 assert(not c.decode(bad,{max_bytes=#bad,checkpoint=function() end}))
end
print('PASS bounded cooperative whitespace boundaries and strict JSON whitespace')
