local manager=require('lua_repl_mcp.manager')
local transport=require('lua_repl_mcp.client_transport')
local c=require('lua_repl_mcp.codec')
local null=require('lua_repl_mcp').null
local b={clock=function() return 0 end,cwd='/'}
function b:allocate() return {state='idle',created_paths={}} end
function b:execute(w) w.state='running'; return 1 end
function b:step() end
function b:shutdown() return true end
local m=manager.new{supervisor=b,limits={input_bytes=4096,values_bytes=1024,
 diagnostic_bytes=256,max_depth=8,worker_bytes=69632,response_bytes=74240,output_bytes=74241}}
local r=m:accept('session_create',{})
local v=m:commit(r,function() return true end); local id=v.session_id
local run=m:accept('session_execute',{session_id=id,code='',wait_timeout_ms=0})
m:commit(run,function() return true end)
local s=m.sessions[id]
s.worker.state='idle'; s.worker.result={status='completed',values=c.array({null,c.object({}),c.array({}),42})}
m:refresh()
-- Oversized ownership metadata must not turn snapshotting into serialization,
-- nor consuming a preflight replacement into consuming the retained result.
s.execution.payload.notice=string.rep('c',80000)
local t=transport.new(m,{read=function() return nil,'again' end,write=function() return nil,'again' end})
t:submit('overflow','session_wait',{session_id=id,wait_timeout_ms=0})
assert(t:step(function() end) and not t.closed)
assert(c.decode(t.queue[1].text).result.structuredContent.error.code=='limit_exceeded')
assert(s.execution.payload and m.slots.ordinary==0)
s.execution.payload.notice=nil
local wait=m:accept('session_wait',{session_id=id,wait_timeout_ms=0})
local preview=m:preview(wait)
assert(preview.values[1]==null and c.kind(preview.values[2])=='object' and c.kind(preview.values[3])=='array')
preview.values[4]=99
assert(m:preview(wait).values[4]==42,'snapshot must not alias owned tables')
assert(not m:commit(wait,function() return false end) and s.execution.payload)
assert(m:commit(wait,function(v) return v.values[4]==42 end))
assert(not s.execution.payload)
print('PASS snapshot_shape_null_isolation_overflow_no_consumption_failed_send_retry')
