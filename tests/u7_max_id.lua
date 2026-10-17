-- Maximum legal ID within each actual request frame, not raw ID length.
local c=require('lua_repl_mcp.codec')
local p=require('lua_repl_mcp.protocol')
local errors=require('lua_repl_mcp.errors')
local function check(I,R,escaped)
 local request={jsonrpc='2.0',id='',method='tools/call',params={name='session_list',arguments=c.object({})}}
 local overhead=#assert(c.encode(request))
 local width=escaped and 2 or 1
 local n=(I-overhead)//width
 request.id=string.rep(escaped and '\\' or 'i',n)
 local frame=assert(c.encode(request,{max_bytes=I}))
 assert(#frame<=I and #frame+width>I)
 local D=I>4096 and 65536 or 256
 local payloads={
  errors.failure(errors.new('invalid_arguments',string.rep('"',D),'validation','not_started',nil,D)),
  errors.failure(errors.new('lua_runtime_error',string.rep('\0',D),'execution','started',nil,D)),
  errors.failure(errors.new('result_serialization_error',string.rep('\\',D+1),'serialization','completed',nil,D)),
  {status='killed',process_exit_confirmed=false,notice='Worker exit was not confirmed; external side effects may continue. Descendant termination is not guaranteed.'},
  {error={code='stdio_setup_failed',message='setup',created_files=c.array({'/'..string.rep('p',I//2)}),created_files_complete=false}},
  {sessions=c.array({{session_id='session-1-1',cwd='/'..string.rep('c',R//2),session_status='idle'}})}
 }
 for i,payload in ipairs(payloads) do
  local encoded,original=assert(p.encode_result(request.id,payload,{max_bytes=R,max_depth=160}))
  local wire=assert(c.decode(encoded,{max_bytes=R,max_depth=160}))
  assert(wire.id==request.id)
  local duplicate=assert(c.decode(wire.result.content[1].text,{max_bytes=R,max_depth=160}))
  assert(c.encode(duplicate,{max_bytes=R})==c.encode(wire.result.structuredContent,{max_bytes=R}))
  if i==6 then assert(not original and duplicate.error.code=='limit_exceeded') end
  assert(#encoded<=R)
 end
 print('MEASURE max_ID_input='..I..' request='..#frame..' raw_ID='..n..' escaped='..tostring(escaped)..' error_notice_metadata_cases=6')
end
check(4096,16000,false); check(4096,16000,true)
-- Default maximum ID plus diagnostics/notices: no max-values fit claim.
check(16*1048576,require('lua_repl_mcp.limits').connection().response_bytes,false)
print('PASS max_legal_ID_errors_notices_metadata_duplicate_equality_and_fallback')
