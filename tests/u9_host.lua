-- Runs inside the C host with only installed pure Lua modules visible.
local c=require('lua_repl_mcp.codec')
local function msg(id,method,params) return assert(c.encode{jsonrpc='2.0',id=id,method=method,params=params})..'\n' end
local function execute(id,code) return msg(id,'tools/call',{name='repl_execute',arguments={code=code}}) end
local data=msg(1,'initialize',{protocolVersion='2025-11-25',capabilities={},clientInfo={name='host',version='1'}})
 ..msg(nil,'notifications/initialized',{})
 ..execute(2,'host_value=host_api(host_value); return host_value')
 ..msg(3,'tools/call',{name='repl_close',arguments={}})
 ..execute(4,'host_value=host_value+1')..'{"jsonrpc":'
local writes,flushed={},false
local result=require('lua_repl_mcp.handler').serve{
 read=function(n) local s=data:sub(1,n); data=data:sub(n+1); return s end,
 write=function(s) writes[#writes+1]=s; return #s end,
 flush=function() flushed=true; return true end,
}
assert(result.reason=='close_requested' and result.acknowledgement_sent and flushed)
assert(host_value==110 and host_handle_alive())
local output=table.concat(writes)
assert(output:find('"closing"',1,true)) -- ack exists before parent cleanup
assert(#result.pending_messages==1 and result.pending_bytes=='{"jsonrpc":')
local pending=assert(c.decode(result.pending_messages[1]))
assert(load(pending.params.arguments.code))(); assert(host_value==111)
local completed=assert(c.decode(result.pending_bytes..'"2.0","id":5,"method":"ping"}'))
assert(completed.id==5 and completed.method=='ping')
for k in pairs(package.loaded) do
 assert(not k:match('^posix') and not k:match('lua_repl_mcp.manager') and not k:match('lua_repl_mcp.worker'))
end
assert(host_handle_alive()); host_value=nil -- parent-chosen reset, not handler action
assert(host_value==nil)
print('PASS native_host_state_thread_handle_close_ack_complete_partial_handoff_parent_reset_shutdown')
