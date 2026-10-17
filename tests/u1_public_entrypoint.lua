-- U1 public entry-point baseline; run from the repository root with Lua 5.4.
-- Deliberately exclude installed Lua modules and all native loaders.
package.path = os.getenv('U9_INSTALLED_LUA_PATH') or './?.lua;./?/init.lua'
package.cpath = ''
package.searchers = { package.searchers[1], package.searchers[2] }

local api = require('lua_repl_mcp')
assert(type(api) == 'table', 'public module must return a table')
assert(api.null ~= nil, 'public null sentinel must differ from nil')
assert(rawequal(api.null, require('lua_repl_mcp').null),
       'public null sentinel must have stable identity')
print('PASS u1_public_null_entrypoint')
