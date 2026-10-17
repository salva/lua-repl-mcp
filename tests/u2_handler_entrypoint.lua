-- U2 prerequisite regression: the documented embedding entry point must load
-- without a manager, installed Lua modules, or native loaders (SPEC 14.5).
-- Run from repository root: lua5.4 tests/u2_handler_entrypoint.lua
package.path = os.getenv('U9_INSTALLED_LUA_PATH') or './?.lua;./?/init.lua'
package.cpath = ''
package.searchers = { package.searchers[1], package.searchers[2] }

local handler = require('lua_repl_mcp.handler')
assert(type(handler) == 'table', 'handler module must return a table')
assert(type(handler.serve) == 'function', 'handler must expose serve(adapter, options)')

-- EOF is a lifecycle return, never permission to clean up parent resources.
local cleanup_calls = 0
local lifecycle = handler.serve({
  read = function(n)
    assert(type(n) == 'number' and n > 0 and n % 1 == 0,
           'read must be called as a plain function with a positive bound')
    return nil, 'eof'
  end,
  write = function(bytes)
    assert(type(bytes) == 'string', 'write must be called as a plain function')
    return #bytes
  end,
  flush = function(...) assert(select('#', ...) == 0); return true end,
  close = function() cleanup_calls = cleanup_calls + 1 end,
  shutdown = function() cleanup_calls = cleanup_calls + 1 end,
})
assert(type(lifecycle) == 'table' and lifecycle.reason == 'eof')
assert(lifecycle.acknowledgement_sent == false)
assert(type(lifecycle.pending_messages) == 'table' and #lifecycle.pending_messages == 0)
assert(lifecycle.pending_bytes == '')
assert(cleanup_calls == 0, 'parent owns cleanup on EOF')
print('PASS u2_handler_entrypoint_and_parent_owned_eof')
