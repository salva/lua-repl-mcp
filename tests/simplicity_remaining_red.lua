-- Remaining simplicity local defects; pure reproduction, no production edits.
local c=require('lua_repl_mcp.codec')
local h=require('lua_repl_mcp.handler')
local e=require('lua_repl_mcp.evaluator')
local failures=0
local function check(name,ok,detail)
 print((ok and 'PASS ' or 'FAIL ')..name..' '..(detail or ''))
 if not ok then failures=failures+1 end
end
local function serve(messages,options)
 local input=table.concat(messages,'\n')..'\n'; local pos=1; local out={}
 local result=h.serve({read=function(n)
  if pos>#input then return nil,'eof' end
  local s=input:sub(pos,pos+n-1); pos=pos+#s; return s
 end,write=function(s) out[#out+1]=s; return #s end,flush=function() return true end},options)
 local replies={}
 for line in table.concat(out):gmatch('[^\n]+') do
  local r=assert(c.decode(line,{max_bytes=40000000})); replies[r.id]=r
 end
 return replies,result
end
local init=assert(c.encode{jsonrpc='2.0',id=1,method='initialize',params={protocolVersion='2025-11-25',capabilities={},clientInfo={name='red',version='1'}}})
local initialized='{"jsonrpc":"2.0","method":"notifications/initialized"}'
do
 local replies,result=serve({init,initialized,'{"jsonrpc":"2.0","id":2,"method":"tools/list"}'},{evaluator={max_depth=1}})
 check('F06_depth1_discovery_tools_shape',replies[2] and replies[2].result and replies[2].result.tools~=nil,'handler='..result.reason)
 assert(c.encode(replies[2].result.tools)==c.encode(assert(c.decode(require('lua_repl_mcp.direct_schemas')))))
end
do
 -- Legal whitespace raises raw frame above the default 16MiB, but below
 -- explicitly configured input. A small semantic ping avoids large snapshots.
 local ping='{"jsonrpc":"2.0","id":3,"method":"ping"}'..string.rep(' ',16*1048576)
 local replies,result=serve({ping},{input_bytes=18*1048576})
 check('F05_effective_handler_input_limit',replies[3] and replies[3].result~=nil,'handler='..result.reason)
end
do
 local old=rawget(_G,'admitted_input_bytes'); _G.admitted_input_bytes=1
 local ok,v=pcall(e.from_json,'{"code":"return 73"}')
 _G.admitted_input_bytes=old
 check('F05_from_json_ignores_ambient_global',ok and v.status=='completed' and v.values[1]==73,ok and tostring(v.error and v.error.code) or tostring(v))
end
do
 -- Valid floor diagnostic allowance; ASCII and escaping expansion boundaries.
 for _,key in ipairs{string.rep('x',1100000),string.rep('"',200000),string.rep('"',100)} do
  _G.simplicity_path_key=key
  local v=e.execute({code='simplicity_effect=73; return {[simplicity_path_key]=function() end}'},{max_bytes=16,diagnostic_bytes=49})
  local encoded,problem=c.encode(v,{max_bytes=1049142,max_depth=132})
  check('F04_optional_path_private_frame_fit_'..#key,encoded~=nil,'path_bytes='..tostring(v.error and v.error.path and #v.error.path)..' encode='..tostring(problem and problem.reason))
  check('F04_completed_effect_and_recovery_'..#key,v.error and v.error.code=='result_serialization_error' and v.error.execution_state=='completed' and _G.simplicity_effect==73 and e.execute{code='return 74'}.values[1]==74)
 end
 _G.simplicity_path_key=nil; _G.simplicity_effect=nil
end
do
 -- Compact newline escapes fit ingress while canonical encoding expands beyond
 -- its default byte bound. Exercise protocol -> handler -> evaluator, not a flag.
 local arg=string.rep('\n',2900000)
 local call=assert(c.encode({jsonrpc='2.0',id=4,method='tools/call',params={name='repl_execute',arguments={code='return #(...)',args=c.array{arg}}}},{max_bytes=20000000})):gsub('\\u000a','\\n')
 assert(#call<16*1048576)
 local replies=serve({init,initialized,call},{})
 local v=replies[4] and replies[4].result and replies[4].result.structuredContent
 check('F05_embedded_admitted_expansion_not_recharged',v and v.status=='completed' and v.values[1]==#arg)
 local text=assert(c.encode({code='return #(...)',args=c.array{arg}},{max_bytes=20000000})):gsub('\\u000a','\\n')
 local v=e.from_json(text)
 check('F05_from_json_raw_input_expansion_not_recharged',v.status=='completed' and v.values[1]==#arg)
end
assert(failures==0,tostring(failures)..' remaining local simplicity checks failed')
