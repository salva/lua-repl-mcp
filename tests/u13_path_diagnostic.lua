-- Maximal legal library creation path (OS rejection, not a legal filesystem path)
-- and full diagnostic budget through actual guardian/worker.
local c=require('lua_repl_mcp.codec')
local G=require('lua_repl_mcp.guardian')
local M=require('lua_repl_mcp.manager')
local x=require('lua_repl_mcp.worker_posix')
local b=G.new{}; local m=M.new{supervisor=b}
local function take(r)
 local stop=x.now()+90
 repeat local v=m:commit(r,function() return true end); if v then return v end; m:step(0); assert(x.now()<stop,'record watchdog') until false
end
local ok,err=pcall(function()
 local I=b.limits.input_bytes
 local empty=assert(c.encode({cwd=''}))
 local options={cwd='/'..string.rep('x',I-#empty-1)}
 assert(#assert(c.encode(options))==I)
 local start=x.now()
 local rejected=take(m:accept('session_create',options))
 -- Linux exec argument ceiling rejects the complete bootstrap before cwd setup.
 -- This is an honest spawn failure, not evidence that a filesystem path exists.
 assert(rejected.error and rejected.error.reason=='spawn_failed' and rejected.process_exit_confirmed)
 print('OBS maximum_library_creation_path_input='..I..' bytes='..#options.cwd..' seconds='..(x.now()-start))
 local setup=take(m:accept('session_create',{cwd='/'..string.rep('x',4096)}))
 assert(setup.error.reason=='cwd_setup_failed' and setup.process_exit_confirmed)
 local id=assert(take(m:accept('session_create',{})).session_id)
 local E=b.limits.diagnostic_bytes
 local result=take(m:accept('session_execute',{session_id=id,code='error(string.rep("x",'..E..'),0)'}))
 print('OBS diagnostic_status='..tostring(result.status)..' code='..tostring(result.error and result.error.code))
 assert(result.status=='failed' and result.error.code=='lua_runtime_error')
 local n=#result.error.message+#(result.error.traceback or '')
 assert(n==E,'expected complete diagnostic budget, got '..n)
 assert(result.session_usable)
 assert(take(m:accept('session_execute',{session_id=id,code='return 73'})).values[1]==73)
 assert(take(m:accept('session_kill',{session_id=id})).process_exit_confirmed)
 print('PASS maximum_legal_creation_record_os_failure_full_diagnostic_budget_recovery E='..E)
end)
b:shutdown(); assert(ok,err)
