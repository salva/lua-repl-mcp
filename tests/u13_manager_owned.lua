-- The manager alone transfers its detached library data to a guardian mirror.
local G=require('lua_repl_mcp.guardian')
local C=require('lua_repl_mcp.codec')
local b=G.new{clock=function() return 0 end}
local m=require('lua_repl_mcp.manager').new{supervisor=b}
local ok,err=pcall(function()
 local w={allocation_generation=1,state='idle',execution_generation=0,pending=''}
 b.by_id[1]=w
 local s={id='owned',worker=w,generation=0,cwd='/'}
 m.sessions.owned=s; m.order={s}
 local input={session_id='owned',code='return ...',args=C.array{C.array{7}}}
 local r=m:accept('session_execute',input)
 input.code='error()'; input.args[1][1]=99
 assert(b.commands[1].input.code=='return ...' and b.commands[1].input.args[1][1]==7)
 assert(s.generation==1 and r.execution.generation==1)
 local n=#b.commands
 assert(m:accept('session_execute',{session_id='owned',code=false}).response.error.code=='invalid_arguments')
 assert(#b.commands==n and s.generation==1)
 w.state='idle'; w.execution_generation=1
 b.command_capacity=n
 local rejected=m:accept('session_execute',{session_id='owned',code='return 1'})
 assert(rejected.response.error.code=='transport_error')
 assert(s.generation==1 and s.execution==r.execution and not rejected.execution)
 assert(w.execution_generation==1 and #b.commands==n)
 print('PASS manager_owned_detached_invalid_queue_failure')
end)
b:shutdown(); assert(ok,err)
