-- Native command preparation must relinquish control before dispatch.
local S=require('lua_repl_mcp.worker_supervisor')
local c=require('lua_repl_mcp.codec')
local now=0
local s=S.new{clock=function() return now end}
local original=assert(c.json_data(assert(c.encode({jsonrpc='2.0',method='tools/call',params={name='session_execute',arguments={code='return 1',args=c.array{string.rep('x',262144)}}}}))))
local function prepare(mode)
 now=0
 local w={state='idle',allocation_generation=1,execution_generation=0,created_paths={},pending=''}
 local co=coroutine.create(function() return s:execute(w,nil,10,original,coroutine.yield) end)
 local ok,value=coroutine.resume(co); assert(ok,value)
 assert(coroutine.status(co)=='suspended' and w.pending=='' and w.execution_generation==0,'native preparation dispatched synchronously')
 if mode=='abort' then s:abort(w,'request_cancelled',0)
 elseif mode then now=mode end
 local turns=1
 while coroutine.status(co)~='dead' do ok,value=coroutine.resume(co); assert(ok,value); turns=turns+1; assert(turns<100) end
 if mode then assert(not value and w.state=='terminating' and w.pending=='' and w.execution_generation==0)
 assert(w.failure==(mode=='abort' and 'request_cancelled' or 'execution_timeout'))
 else assert(value==1 and w.state=='running' and #w.pending>262144) end
 return turns
end
print('PASS native_command_preparation_slices='..prepare(false)..' abort_slices='..prepare('abort')..' equal='..prepare(10)..' after='..prepare(10.001))
