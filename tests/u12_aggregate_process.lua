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
 -- Results are transferred once, not periodically resent as full snapshots.
 -- Keep stepping the actual guardian while retaining all nine payloads.
 local transfers=b.result_transfers
 assert(transfers==9)
 for _=1,40 do b:step(1) end
 assert(b.result_transfers==transfers,'retained result retransmitted')
 for _,w in ipairs(workers) do assert(#w.result.values[1]==1048572) end
 assert(not b.closed)
 print('PASS real_guardian_nine_maximal_results_survive_aggregate_frame_boundary')
end)
local clean,why=pcall(function() assert(b:shutdown()) end)
assert(ok,err); assert(clean,why)
