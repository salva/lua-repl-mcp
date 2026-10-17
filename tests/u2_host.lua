-- Real supplied control channel: stdin/stdout belong to this parent fixture.
package.path=os.getenv('U9_INSTALLED_LUA_PATH') or './?.lua;./?/init.lua'
local handler=require('lua_repl_mcp.handler')
local codec=require('lua_repl_mcp.codec')
local control_in,control_out=io.stdin,io.stdout
local thread=coroutine.running()
host_value=10
host_block=function()
 assert(coroutine.running()==thread)
 -- Native/OS blocking on invoking thread; no protocol service during this call.
 assert(os.execute('sleep 0.3'))
 host_value=host_value+1
end
local lifecycle=handler.serve({
 read=function(n) local s=control_in:read(1);if not s then return nil,'eof' end;return s end,
 write=function(s) local ok,e=control_out:write(s);if not ok then return nil,e end;return #s end,
 flush=function() return control_out:flush() end,
},{instructions='Fixture exposes host_value and host_block(). Parent owns channel.'})
assert(lifecycle.reason=='close_requested' and lifecycle.acknowledgement_sent)
assert(host_value==11)
host_value=12 -- host continued, then deliberately selected reset and cleanup
host_value=nil;host_block=nil
control_out:write(assert(codec.encode({parent_continued=true,reason=lifecycle.reason}))..'\n')
control_out:flush()
-- Parent, not handler, closes its channel and exits.
control_in:close();control_out:close()
