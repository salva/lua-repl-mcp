-- Manager mirrors own logical dispatch, never worker-wire serialization.
local G=require('lua_repl_mcp.guardian')
local P=require('lua_repl_mcp.worker_protocol')
local C=require('lua_repl_mcp.codec')
local b=G.new{clock=function() return 0 end}
local ok,err=pcall(function()
 local w={allocation_generation=1,state='idle',execution_generation=0,pending=''}
 b.by_id[1]=w
 local encode=P.encode
 P.encode=function() error('mirror attempted worker encoding') end
 local success,value=pcall(function() return b:execute(w,{code='return ...',args=C.array{C.array{7}}},10) end)
 P.encode=encode
 assert(success,value); assert(value==1 and w.state=='running' and w.pending=='')
 local cmd=b.commands[1]
 assert(cmd.generation==1 and cmd.input.args[1][1]==7)
 local w2={allocation_generation=2,state='idle',execution_generation=0,pending=''}; b.by_id[2]=w2
 local args=C.array{C.array{8}}
 assert(b:execute(w2,{code='return ...',args=args},10)==1)
 args[1][1]=99; assert(b.commands[2].input.args[1][1]==8,'queued library data aliases caller')
 local w3={allocation_generation=3,state='idle',execution_generation=0,pending=''}; b.by_id[3]=w3
 local n=#b.commands
 assert(not b:execute(w3,{code=false},10)); assert(#b.commands==n and w3.execution_generation==0)
 local body=assert(C.json_data('{"jsonrpc":"2.0","method":"tools/call","params":{"name":"session_execute","arguments":{"code":"return 9"}}}'))
 assert(b:execute(w3,nil,10,body)==1)
 assert(b.commands[3].request==body and not b.commands[3].input)
 assert(not b:execute(w3,{code='return 1'},10))
 local w4={allocation_generation=4,state='idle',execution_generation=0,pending=''}; b.by_id[4]=w4
 n=#b.commands
 assert(not b:execute(w4,{code='return 1'},0))
 assert(w4.state=='terminating' and w4.failure=='execution_timeout' and w4.execution_generation==0 and #b.commands==n)
 local w5={allocation_generation=5,state='idle',execution_generation=0,pending=''}; b.by_id[5]=w5
 local capacity=b.command_capacity; b.command_capacity=#b.commands
 assert(not pcall(function() b:execute(w5,{code='return 1'},10) end))
 b.command_capacity=capacity
 assert(w5.state=='idle' and w5.execution_generation==0 and #b.commands==n)
 print('PASS mirror_no_worker_encoding_fresh_library_invalid_original_busy_generations_deadline_queue_failure')
end)
b:shutdown(); assert(ok,err)
