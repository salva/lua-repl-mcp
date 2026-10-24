-- Nonintegral fast conversion must not bypass strict grammar/integer checks.
local c=require('lua_repl_mcp.codec')
for _,text in ipairs{'1e-7','-1e-7','0.5','4503599627370495.5','1.25e-200'} do
 assert(c.decode(text)==tonumber(text))
end
for _,text in ipairs{'9007199254740992','9007199254740993','9.007199254740992e15','90071992547409920e-1','1e400','01.5','1.e-7','1e-7x','+0.5'} do
 assert(c.decode(text)==nil,text)
end
assert(c.decode('9007199254740991')==9007199254740991)
assert(c.decode('1e-9999')==0)
print('PASS finite nonintegral conversion and exact integer/grammar rejection')
