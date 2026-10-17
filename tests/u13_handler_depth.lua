-- Actual blocking attachment with all native loading disabled.
package.cpath=''
package.searchers={package.searchers[1],package.searchers[2]}
local h=require('lua_repl_mcp.handler')
local c=require('lua_repl_mcp.codec')
local function encode(v,d) return assert(c.encode(v,{max_depth=d+5,max_bytes=2000000}))..'\n' end
for _,d in ipairs{1,128,256,512} do
 local v=7; for _=1,d do v=c.array{v} end
 local function call(id,args) return {jsonrpc='2.0',id=id,method='tools/call',params={name='repl_execute',arguments={code='return ...',args=c.array{args}}}} end
 local init={jsonrpc='2.0',id=1,method='initialize',params={protocolVersion='2025-11-25',capabilities={},clientInfo={name='pure-depth',version='1'}}}
 local input=encode(init,d)..encode({jsonrpc='2.0',method='notifications/initialized'},d)..encode(call(2,v),d)..encode(call(3,c.array{v}),d)..encode({jsonrpc='2.0',id=4,method='tools/call',params={name='repl_close',arguments={}}},d)
 local output={}; local pos=1
 local adapter={read=function(n) if pos>#input then return nil end; local s=input:sub(pos,pos+n-1); pos=pos+#s; return s end,write=function(s) output[#output+1]=s; return #s end,flush=function() return true end}
 local result=h.serve(adapter,{input_bytes=1500000,response_bytes=10221184,evaluator={max_depth=d}})
 assert(result.acknowledgement_sent,result.reason)
 local responses={}
 for line in table.concat(output):gmatch('[^\n]+') do local r=assert(c.decode(line,{max_depth=d+4,max_bytes=10221184})); responses[r.id]=r end
 local value=responses[2].result.structuredContent
 assert(value.status=='completed')
 local leaf=value.values[1]; for _=1,d do leaf=leaf[1] end; assert(leaf==7)
 assert((responses[3] and (responses[3].error or responses[3].result.isError)) or (responses[require('lua_repl_mcp').null] and responses[require('lua_repl_mcp').null].error))
 assert(not package.loaded['lua_repl_mcp.worker_posix'] and not package.loaded.posix)
 print('PASS pure_blocking_handler_configured_depth_roundtrip_reject_next_'..d)
end
