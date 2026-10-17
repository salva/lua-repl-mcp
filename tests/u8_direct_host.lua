-- Actual host-supplied dedicated pipe descriptors, never protocol stdin/stdout.
local u=require('posix.unistd')
local c=require('lua_repl_mcp.codec')
local rd=assert(tonumber(os.getenv('U8_READ_FD')))
local wr=assert(tonumber(os.getenv('U8_WRITE_FD')))
local owner=coroutine.running()
host_value=10
host_api=function(n) assert(coroutine.running()==owner); host_value=host_value+n; return host_value end
local result=require('lua_repl_mcp.handler').serve{
 read=function(n) local s,e=u.read(rd,n); if s=='' then return nil,'eof' end; return s,e end,
 write=function(s) return u.write(wr,s) end,
 flush=function() return true end,
}
assert(result.reason=='close_requested' and result.acknowledgement_sent)
assert(host_value==12)
-- Handles remain open, globals intact, and raw trailing messages unexecuted.
assert(u.write(wr,'')==0)
assert(#result.pending_messages==1 and result.pending_bytes=='{"partial":')
local pending=assert(c.decode(result.pending_messages[1]))
assert(pending.params.arguments.code=='host_value=999')
-- Parent resumes buffered messages, not the handler, then selects reset.
local chunk=assert(load(pending.params.arguments.code)); chunk()
assert(host_value==999)
assert(u.write(wr,assert(c.encode({parent_continued=true,host_value=host_value,
 pending_bytes=result.pending_bytes,pending_messages=result.pending_messages}))..'\n'))
host_value=nil; host_api=nil
u.close(rd); u.close(wr)
