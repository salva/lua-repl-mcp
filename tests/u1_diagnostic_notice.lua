-- Regression: reserving the loss notice may itself truncate diagnostics.
package.path='./?.lua;./?/init.lua'
package.cpath=''
package.searchers={package.searchers[1],package.searchers[2]}
local errors=require('lua_repl_mcp.errors')
local limit=80
local original=string.rep('a',70)..'\255'
-- Escaped source is 74 bytes, below 80. The required loss notice leaves
-- insufficient room, so the constructor drops source diagnostic text.
local e=errors.new('lua_runtime_error',original,'execution','started',nil,limit)
assert(#e.message+#(e.traceback or '')<=limit)
assert(e.data_preserved==false)
assert(e.invalid_bytes_escaped==true)
assert(e.message:find(errors.notice,1,true))
assert(e.truncated==true,
  'diagnostic truncation must be flagged when notice reservation discards original text')
print('PASS diagnostic_notice_truncation')
