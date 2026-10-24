-- Test-only native host readiness variants; executed by u14_native_host.c.
local c=require('lua_repl_mcp.codec')
local mode=assert(host_argv[1])
if mode=='late' then os.execute('sleep 0.2') end
local v={type='ready',protocol_version=mode=='version' and 2 or 1,
 allocation_generation=tonumber(os.getenv('LUA_REPL_MCP_ALLOCATION_GENERATION'))+(mode=='generation' and 1 or 0),cwd=host_cwd}
local text=mode=='malformed' and '{bad}\n' or assert(c.encode(v))..'\n'
local at=1
while at<=#text do at=at+native_write(text:sub(at)) end
native_flush()
-- Never evaluate commands; supervisor must dispose an invalid/late allocation.
native_read(1)
