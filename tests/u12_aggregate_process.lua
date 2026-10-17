-- Real guardian/exec workers: aggregate result bytes exceed one channel frame.
local G=require('lua_repl_mcp.guardian')
local x=require('lua_repl_mcp.worker_posix')
local b=G.new{limits={input_bytes=1024,values_bytes=1048576,diagnostic_bytes=128,
 worker_bytes=3*1048576,response_bytes=8*1048576,output_bytes=9*1048576}}
local ok,err=pcall(function()
 local workers={}
 for i=1,9 do workers[i]=b:allocate{} end
 local function await(state)
  local deadline=x.now()+20
  repeat
   b:step(5)
   local all=true
   for _,w in ipairs(workers) do
    assert(w.state~='dead',w.failure)
    if w.state~=state then all=false end
   end
   if all then return end
   assert(x.now()<deadline,'real aggregate watchdog')
  until false
 end
 await('idle')
 for _,w in ipairs(workers) do
  assert(b:execute(w,{code='return string.rep("x",1048572)'},nil))
 end
 await('idle')
 for _,w in ipairs(workers) do assert(#w.result.values[1]==1048572) end
 -- A further empty command batch forces a snapshot containing all nine retained
 -- maximal results, rather than only staggered completion reports.
 local wire=require('lua_repl_mcp.guardian_channel')
 local receive=wire.receive; local completed=0
 wire.receive=function(ch,accept)
  return receive(ch,function(items,done)
   accept(items,done)
   if ch==b.channel and done then completed=completed+1 end
  end)
 end
 local deadline=x.now()+20
 local passed,why=pcall(function()
  repeat b:step(5); assert(x.now()<deadline,'retained aggregate watchdog') until completed>=2
 end)
 wire.receive=receive
 assert(passed,why)
 assert(not b.closed)
 print('PASS real_guardian_nine_maximal_results_survive_aggregate_frame_boundary')
end)
local clean,why=pcall(function() assert(b:shutdown()) end)
assert(ok,err); assert(clean,why)
