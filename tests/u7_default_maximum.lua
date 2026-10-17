-- Default coupled budgets: construct a legal result and an ID from a legal
-- input frame, then measure the complete response with the production encoder.
local c=require('lua_repl_mcp.codec')
local p=require('lua_repl_mcp.protocol')
local V=16*1048576
local defaults=require('lua_repl_mcp.limits').connection()
local R=defaults.response_bytes
assert(R==128*1048576 and defaults.worker_bytes==64*1048576 and defaults.output_bytes==256*1048576)
local function request(id)
 return {jsonrpc='2.0',id=id,method='tools/call',params={name='session_wait',
  arguments={session_id='session-1-1',wait_timeout_ms=0}}}
end
local empty=assert(c.encode(request('')))
local id=string.rep('i',V-#empty)
local input=assert(c.encode(request(id),{max_bytes=V}))
assert(#input==V)
local values=c.array({string.rep('\\',(V-4)//2)})
local encoded_values=assert(c.encode(values,{max_bytes=V}))
assert(#encoded_values==V)
local payload={status='completed',values=values,session_id='session-1-1',
 session_status='idle',session_usable=true}
local result=assert(p.tool_result(payload))
local full=assert(c.encode({jsonrpc='2.0',id=id,result=result},
 {max_bytes=80*1048576,max_depth=160}))
print('MEASURE legal_request='..#input..' legal_values='..#encoded_values..
 ' complete_response='..#full..' response_bound='..R..' excess='..(#full-R))
local bounded,original=p.encode_result(id,payload)
assert(bounded and original and #bounded==#full)
local wire=assert(c.decode(bounded,{max_bytes=R,max_depth=160}))
assert(wire.id==id and wire.result.structuredContent.status=='completed')
assert(c.encode(wire.result.structuredContent,{max_bytes=R})==wire.result.content[1].text)
print('PASS production_defaults_maximum_legal_ID_escape_heavy_values_original_success')
