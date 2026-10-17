-- Independent U2 review: explicit non-object arguments must not close the host
-- attachment. SPEC 14.1/14.2; schemas/api.json repl_close requires object.
package.path='./?.lua;./?/init.lua'
package.cpath=''
package.searchers={package.searchers[1],package.searchers[2]}
local handler=require('lua_repl_mcp.handler')
local codec=require('lua_repl_mcp.codec')
local function frame(v) return assert(codec.encode(v))..'\n' end
local input=frame({jsonrpc='2.0',id=1,method='initialize',params={
 protocolVersion='2025-11-25',capabilities={},clientInfo={name='independent-review',version='1'}}})..
 frame({jsonrpc='2.0',method='notifications/initialized'})..
 frame({jsonrpc='2.0',id=2,method='tools/call',params={name='repl_close',arguments=false}})..
 frame({jsonrpc='2.0',id=3,method='tools/call',params={name='repl_execute',arguments={code='u2_review_after_invalid_close=true; return 42'}}})..
 frame({jsonrpc='2.0',id=4,method='tools/call',params={name='repl_close',arguments={}}})
local output=''
local result=handler.serve({
 read=function(n) if #input==0 then return nil,'eof' end;local s=input:sub(1,n);input=input:sub(#s+1);return s end,
 write=function(s) output=output..s;return #s end,
 flush=function() return true end,
 close=function() error('handler must not close adapter') end,
})
local replies={}
for line in output:gmatch('([^\n]+)\n') do replies[#replies+1]=assert(codec.decode(line)) end
local rejected=replies[2].result
print('Observed false-argument close status: '..tostring(rejected.structuredContent.status))
print('Observed lifecycle close_request_id: '..tostring(result.close_request_id))
print('Observed trailing execution: '..tostring(u2_review_after_invalid_close))
assert(rejected.isError==true and rejected.structuredContent.error.code=='invalid_arguments',
 'explicit false arguments must be rejected, not defaulted to an empty object')
assert(u2_review_after_invalid_close==true and replies[3].result.structuredContent.values[1]==42)
assert(result.reason=='close_requested' and result.close_request_id==4 and result.acknowledgement_sent)
print('PASS explicit_false_close_arguments_rejected_without_stopping_admission')
