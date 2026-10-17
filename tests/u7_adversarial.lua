local c=require('lua_repl_mcp.codec')
local evaluator=require('lua_repl_mcp.evaluator')
local errors=require('lua_repl_mcp.errors')
local protocol=require('lua_repl_mcp.protocol')
local V=16*1048576
-- Each test generates encoded values at/below bound, not raw-size assertions.
for _,case in ipairs({{name='backslash',byte=92,width=2},{name='control',byte=0,width=6}}) do
 local n=(V-4)//case.width
 local value=string.rep(string.char(case.byte),n)
 local values=c.array({value})
 local encoded=assert(c.encode(values,{max_bytes=V}))
 assert(#encoded==n*case.width+4)
 local payload={status='completed',values=values}
 local text,original=protocol.encode_result('ordinary-id',payload)
 assert(original and text)
 local wire=assert(c.decode(text,{max_bytes=64*1048576,max_depth=160}))
 local duplicate=assert(c.decode(wire.result.content[1].text,{max_bytes=20*1048576,max_depth=160}))
 assert(duplicate.values[1]==wire.result.structuredContent.values[1])
 local overflow=c.encode(c.array({value..string.char(case.byte)}),{max_bytes=V})
 assert(not overflow)
 print('MEASURE '..case.name..' values_bytes='..#encoded..' response_bytes='..#text)
end
for _,depth in ipairs({127,128,129}) do
 local v=0; for _=1,depth do v={v} end
 local encoded=c.encode(v,{max_depth=128})
 assert((encoded~=nil)==(depth<=128))
end
for _,delta in ipairs({-1,0,1}) do
 local err=errors.new('lua_runtime_error',string.rep('"',65536+delta),'execution','started')
 assert(#err.message<=65536 and (err.truncated==true)==(delta==1))
 local text,original=protocol.encode_result(string.rep('\\',8192),{error=err})
 assert(text and original)
end
-- Evaluator owns value overflow semantics and never returns a partial values.
local v=evaluator.execute({code='return string.rep("x",65)'},{max_bytes=64})
assert(v.error.code=='result_serialization_error' and not v.values)
print('PASS default_control_backslash_duplicate_depth_diagnostic_and_value_error_boundaries')
