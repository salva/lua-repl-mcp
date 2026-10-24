-- Private validated snapshots never expose a mutable decoded value.
local c=require('lua_repl_mcp.codec')
local text='{"args":[[1e-7]],"empty":[]}'
local token=assert(c.json_data(text))
local first=assert(c.json_value(token)); first.args[1][1]=99; first.empty[1]=true
local second=assert(c.json_value(token))
assert(second.args[1][1]==1e-7 and #second.empty==0 and c.kind(second.empty)=='array')
assert(c.encode(token)==text and c.json_bytes(token)==#text)
local envelope=assert(c.decode('{"request":'..text..'}',{json_path='/request'}))
local derived=assert(c.json_value(envelope.request)); derived.args[1][1]=42
assert(c.json_value(envelope.request).args[1][1]==1e-7)
assert(c.encode(envelope.request)==text)
print('PASS immutable decoded snapshot detached derivations and exact wire bytes')
