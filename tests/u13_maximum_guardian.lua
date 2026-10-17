-- Actual installed guardian maximum legal values record (not combined stress).
local x=require('lua_repl_mcp.worker_posix')
local G=require('lua_repl_mcp.guardian')
local M=require('lua_repl_mcp.manager')
local null=require('lua_repl_mcp').null
local b=G.new{}
local m=M.new{supervisor=b}
local function take(r)
 local deadline=x.now()+120
 repeat
  local v=m:commit(r,function() return true end)
  if v then return v end
  m:step(0)
  assert(x.now()<deadline,'maximal installed record watchdog')
 until false
end
local ok,err=pcall(function()
 local id=take(m:accept('session_create',{})).session_id
 local started=x.now()
 local r=m:accept('session_execute',{session_id=id,code='return string.rep("x",16777212)',wait_timeout_ms=null})
 local result=take(r)
 assert(result.status=='completed',result.error and result.error.message)
 assert(#result.values[1]==16777212) -- ["..."] is exactly V=16777216
 print('OBS maximum legal values bytes=16777216 elapsed='..(x.now()-started))
 assert(take(m:accept('session_list',{})).sessions)
end)
local clean,why=pcall(function() assert(b:shutdown()) end)
assert(ok,err); assert(clean,why)
print('PASS installed_guardian_maximum_legal_values_record')
