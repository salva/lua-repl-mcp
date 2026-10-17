-- No process acquisition for expired or invalid creation; queued guardian data
-- keeps the original origin and detached complete validated options.
local x=require('lua_repl_mcp.worker_posix')
local S=require('lua_repl_mcp.worker_supervisor')
local G=require('lua_repl_mcp.guardian')
local now=100
local s=S.new{clock=function() return now end,startup_timeout_ms=1000}
local pipe=x.u.pipe
local acquisitions=0
x.u.pipe=function() acquisitions=acquisitions+1; error('unexpected acquisition') end
local ok,err=pcall(function()
 for _,origin in ipairs{98,99} do
  local w=s:allocate({},origin)
  assert(w.state=='dead' and w.failure=='startup_timeout' and not w.pid)
  assert(w.deadline==origin+1 and w.process_exit_confirmed)
 end
 for _,options in ipairs{{cwd=''},{cwd='\255'},{cwd='x\0y'},{stdin_path=false},{unknown='x'}} do
  assert(not pcall(s.allocate,s,options))
 end
 assert(not pcall(s.allocate,s,false))
 assert(not pcall(s.allocate,s,require('lua_repl_mcp').null))
 assert(acquisitions==0)
end)
x.u.pipe=pipe
assert(ok,err)
local b=G.new{startup_timeout_ms=1000}
local success,why=pcall(function()
 local input={cwd='/'}
 local w=b:allocate(input)
 input.cwd='/mutated-after-validation'
 local command=b.commands[1]
 assert(command.options.cwd=='/' and command.started==w.deadline-1)
 -- Hold the queued complete creation past its ORIGINAL startup deadline.
 x.p.poll({},1100)
 local deadline=x.now()+5
 repeat b:step(0); assert(x.now()<deadline) until w.state=='dead'
 assert(w.failure=='startup_timeout' and w.process_exit_confirmed)
 assert(not w.pid,'manager mirror must never own OS worker PID')
end)
local clean,cleanup=pcall(function() assert(b:shutdown()) end)
assert(success,why); assert(clean,cleanup)
print('PASS original_startup_origin_expiry_before_spawn_validated_fresh_creation')
