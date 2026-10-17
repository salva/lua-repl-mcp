-- Independent U1 acceptance regression: rejecting binary keys must still produce
-- a JSON-encodable failure. SPEC 13.4, 13.5, 14.3; PLAN U1 invalid-byte coverage.
package.path='./?.lua;./?/init.lua'
package.cpath=''
package.searchers={package.searchers[1],package.searchers[2]}
local evaluator=require('lua_repl_mcp.evaluator')
local codec=require('lua_repl_mcp.codec')
local cases={
  {'top-level invalid key','return {["\\255"]=1}'},
  {'nested surrogate key','return {outer={["a/\\237\\160\\128~"]=1}}'},
}
local failures=0
for _,case in ipairs(cases) do
  local r=evaluator.execute({code='u1_review_effect=(u1_review_effect or 0)+1; '..case[2]})
  assert(r.status=='failed' and r.error.code=='result_serialization_error')
  assert(r.error.stage=='serialization' and r.error.execution_state=='completed')
  assert(r.values==nil)
  local text,problem=codec.encode(r)
  if not text then
    failures=failures+1
    print('FAIL '..case[1]..': failure response rejected: '..problem.reason..' at '..problem.path)
  else
    assert(codec.decode(text))
    print('PASS '..case[1])
  end
end
local next_result=evaluator.execute({code='return u1_review_effect'})
assert(next_result.values[1]==#cases,'execution must happen once per case and remain usable')
assert(failures==0,failures..' failure responses cannot be serialized')
