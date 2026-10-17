-- SPEC14.4 progressive termination: observe initial signal without killing a PID.
local S=require('lua_repl_mcp.worker_supervisor')
local x=require('lua_repl_mcp.worker_posix')
local b=S.new{clock=function() return 0 end}
local w={state='running',pid=12345,pending='',buffer=''}
local saved=x.s.kill
local sent={}
x.s.kill=function(pid,sig) sent[#sent+1]={pid,sig}; return 0 end
local ok,err=pcall(function() b:abort(w,'session_killed') end)
x.s.kill=saved
assert(ok,err)
print('MEASURE initial_signal='..tostring(sent[1] and sent[1][2])..' required_TERM='..x.s.SIGTERM)
assert(#sent==1 and sent[1][2]==x.s.SIGTERM,
 'SPEC14.4 requires initial TERM, not immediate KILL (20s TERM/10s KILL policy)')
