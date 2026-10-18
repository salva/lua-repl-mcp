-- Batch2 red/green gates: configured user depth and raw-copy boundaries.
package.path=os.getenv('U9_INSTALLED_LUA_PATH') or './?.lua;./?/init.lua'
package.cpath=''
local codec=require('lua_repl_mcp.codec')
local evaluator=require('lua_repl_mcp.evaluator')
local contracts=require('lua_repl_mcp.contracts')
local failures=0
local function check(name,f)
 local ok,e=pcall(f)
 print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(e)))
 if not ok then failures=failures+1 end
end
local function nested(depth)
 local v=7
 for _=1,depth do v={child=v} end
 return v
end
for _,depth in ipairs{126,127,128,129,256,512} do
 check('effective_argument_depth_'..depth,function()
  local original=nested(depth)
  local result=evaluator.execute({code='local v=...; while type(v)=="table" do v=v.child end; return v',args=codec.array{original}}, {max_depth=depth})
  assert(result.status=='completed',result.error and result.error.message)
  assert(result.values[1]==7)
 end)
end
check('raw_copy_fresh_metatable_data',function()
 local calls=0
 local value=setmetatable({child={answer=42}}, {
  __pairs=function() calls=calls+1; error('pairs invoked') end,
  __index=function() calls=calls+1; error('index invoked') end,
  __eq=function() calls=calls+1; error('eq invoked') end})
 local input={code='return ...',args=codec.array{value}}
 local copy=assert(contracts.validate('repl_execute',input))
 assert(calls==0 and not rawequal(copy,input) and not rawequal(copy.args[1],value))
 assert(getmetatable(copy.args[1])==nil and copy.args[1].child.answer==42)
 value.child.answer=99; assert(copy.args[1].child.answer==42)
end)
check('invalid_cycle_rejected',function()
 local v={}; v.child=v
 local result=evaluator.execute{code='return 1',args=codec.array{v}}
 assert(result.error and result.error.code=='invalid_arguments')
end)
print('SUMMARY failures='..failures)
os.exit(failures==0 and 0 or 1)
