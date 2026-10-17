-- Decoder must inspect only six bytes when resolving a surrogate continuation.
-- Keep input alive before stopping GC; count decoder intermediate allocations.
local c=require('lua_repl_mcp.codec')
local function measure(padding)
 local source='"'..string.rep('\\ud83d\\ude00',100)..'"'..string.rep(' ',padding)
 collectgarbage('collect'); collectgarbage('stop')
 local before=collectgarbage('count'); local start=os.clock()
 local result,err=c.decode(source,{max_bytes=#source})
 local allocated=collectgarbage('count')-before
 collectgarbage('restart')
 assert(result,err and err.reason)
 assert(result==string.rep(utf8.char(0x1f600),100))
 print(('OBS surrogate_decode source=%d allocation_KiB=%.3f seconds=%.6f'):format(#source,allocated,os.clock()-start))
 return allocated
end
local small=measure(1024)
local large=measure(131072)
assert(large<small*3+64,'surrogate continuation copies unrelated suffix per pair')
for _,source in ipairs{'"\\ud83d"','"\\ud83d\\u0041"','"\\ud83d\\ude0"','"\\ude00"','"\\ud83dx\\ude00"'} do
 assert(c.decode(source)==nil,'invalid surrogate accepted: '..source)
end
assert(c.decode('"\\ud83d\\ude00" trailing')==nil)
print('PASS surrogate_bounded_lookahead_and_strict_errors')
