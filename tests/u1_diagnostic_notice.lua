-- Regression: reserving the loss notice may itself truncate diagnostics.
package.path=os.getenv('U9_INSTALLED_LUA_PATH') or './?.lua;./?/init.lua'
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

local codec=require('lua_repl_mcp.codec')
local function check(name,message,trace,expected_truncated,expected_escaped,cap)
  cap=cap or 80
  local result=errors.new('lua_runtime_error',message,'execution','started',
    {traceback=trace},cap)
  assert(result.truncated==(expected_truncated or nil),name..': truncation flag')
  assert(result.invalid_bytes_escaped==(expected_escaped or nil),name..': escape flag')
  local altered=expected_truncated or expected_escaped
  if altered then assert(result.data_preserved==false,name..': loss flag')
  else assert(result.data_preserved==nil,name..': unchanged loss flag') end
  assert(#result.message+#(result.traceback or '')<=cap,name..': bound')
  assert(codec.valid_utf8(result.message),name..': message UTF-8')
  assert(codec.valid_utf8(result.traceback or ''),name..': traceback UTF-8')
  if altered then assert(result.message:find(errors.notice,1,true),name..': notice') end
  assert(codec.encode(result),name..': JSON encoding')
  print('PASS '..name)
  return result
end
local budget=80-#errors.notice
-- Exact and neighboring post-notice budgets, with invalid bytes in either field.
for _,delta in ipairs({-1,0,1}) do
  local escaped_length=budget+delta
  check('message_notice_budget_'..delta,string.rep('a',escaped_length-4)..'\255',nil,delta>0,true)
  check('traceback_notice_budget_'..delta,'m',string.rep('t',escaped_length-5)..'\254',delta>0,true)
end
check('traceback_only_notice_truncation','',string.rep('t',70)..'\255',true,true)
check('combined_notice_truncation',string.rep('a',20)..'\255',string.rep('t',40),true,true)
check('both_fields_invalid_short','\255','\254',false,true)
-- Valid diagnostics must not reserve a notice unless actual truncation is needed.
for _,delta in ipairs({-1,0,1}) do
  check('unmodified_limit_'..delta,string.rep('a',40),string.rep('t',40+delta),delta>0,false)
end
local unicode=check('multibyte_clipping',string.rep('😀',10)..'\255',nil,true,true)
assert(unicode.message==string.rep('😀',math.floor(budget/4))..errors.notice)
local minimum=check('minimum_notice_capacity','\255','trace',true,true,#errors.notice)
assert(minimum.message==errors.notice and minimum.traceback==nil)
print('PASS diagnostic_notice_boundary_matrix')
