-- Guardian identity and repeated completion/abort transitions with real workers.
local G=require('lua_repl_mcp.guardian')
local x=require('lua_repl_mcp.worker_posix')
local function turn(b,predicate)
 local deadline=x.now()+8
 repeat b:step(5); assert(x.now()<deadline,'guardian race watchdog') until predicate()
end
local b=G.new{}
local ok,err=pcall(function()
 for i=1,20 do
  local w=b:allocate{}
  turn(b,function() return w.state=='idle' end)
  assert(b:execute(w,{code='return '..i}))
  turn(b,function() return w.state=='idle' end)
  local result=w.result
  assert(result.values[1]==i)
  b:abort(w,'session_killed'); b:abort(w,'shutdown')
  turn(b,function() return w.state=='dead' end)
  assert(w.result.values[1]==i,'completed outcome rewritten')
  assert(w.failure=='session_killed' and w.process_exit_confirmed)
 end
 for i=1,20 do
  local w=b:allocate{}
  turn(b,function() return w.state=='idle' end)
  assert(b:execute(w,{code='while true do end'}))
  b:abort(w,'execution_timeout'); local origin=w.termination_started
  b:abort(w,'shutdown')
  turn(b,function() return w.state=='dead' end)
  assert(w.failure=='execution_timeout' and w.termination_started==origin)
  assert(not w.result and w.process_exit_confirmed)
 end
 print('PASS guardian_40_repeated_completed_outcome_active_abort_freeze_races')
end)
local clean,why=pcall(function() assert(b:shutdown()) end)
assert(ok,err); assert(clean,why)
for _,kind in ipairs{'reused','stale'} do
 local g=G.new{}
 local w=g:allocate{}
 turn(g,function() return w.state=='idle' end)
 g:abort(w,'session_killed')
 turn(g,function() return w.state=='dead' end)
 -- Release command is queued before this injected private command. Neither a
 -- reused allocation nor a stale execute may reach another OS child identity.
 if kind=='reused' then g:queue{op='allocate',id=w.allocation_generation,options={}}
 else g:queue{op='execute',id=w.allocation_generation,input={code='return 99'}} end
 local deadline=x.now()+8; local failed=false
 repeat
  local valid,msg=pcall(g.step,g,5)
  if not valid then assert(tostring(msg):find('guardian lost',1,true)); failed=true end
  assert(x.now()<deadline,'identity watchdog')
 until failed
 assert(g.closed and #g.workers==0)
 print('PASS guardian_'..kind..'_identity_fail_closed_no_worker_pid_fallback')
end
