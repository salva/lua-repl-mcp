local G=require('lua_repl_mcp.guardian')
local M=require('lua_repl_mcp.manager')
local c=require('lua_repl_mcp.codec')
local x=require('lua_repl_mcp.worker_posix')
local null=require('lua_repl_mcp').null
for _,depth in ipairs{1,128,256,512} do
 local limits={max_depth=depth}
 local b=G.new{limits=limits}; local m=M.new{limits=limits,supervisor=b}
 local function take(r)
  local deadline=x.now()+15
  repeat
   local v=m:commit(r,function() return true end)
   if v then return v end
   m:step(0); assert(x.now()<deadline,'depth watchdog')
  until false
 end
 local ok,err=pcall(function()
  local value=7
  for i=1,depth do value=c.array({value}) end
  local v=take(m:accept('session_execute',{code='local v=...; while type(v)=="table" do v=v[1] end; return v',args=c.array({value}),wait_timeout_ms=null}))
  assert(v.status=='completed' and v.values[1]==7,assert(c.encode(v)))
  local bad=c.array({value})
  local r=take(m:accept('session_execute',{code='return 1',args=c.array({bad}),wait_timeout_ms=null}))
  assert(r.error and r.error.code=='invalid_arguments')
 end)
 local clean,why=pcall(function() assert(b:shutdown()) end)
 assert(ok,err); assert(clean,why)
 print('PASS actual_guardian_user_depth_'..depth..'_and_reject_next')
end
