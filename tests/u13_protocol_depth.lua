local c=require('lua_repl_mcp.codec')
local P=require('lua_repl_mcp.protocol')
local null=require('lua_repl_mcp').null
for _,d in ipairs{1,128,256,512} do
 local v=9; for i=1,d do v=c.array({v}) end
 local core=P.new{max_depth=d,names={repl_execute=true},tools={},call=function(_,a)
  return require('lua_repl_mcp.evaluator').execute(a,{max_depth=d})
 end}
 core.state='ready'
 local request={jsonrpc='2.0',id=7,method='tools/call',params={name='repl_execute',arguments={code='return ...',args=c.array({v})}}}
 local text=assert(c.encode(request,{max_depth=d+4}))
 local response=core:handle(text)
 assert(response.result and response.result.structuredContent.status=='completed')
 local result=assert(P.encode_result(7,response.result.structuredContent,{max_depth=d+4,max_bytes=128*1048576}))
 assert(c.decode(result,{max_depth=d+4}))
 request.params.arguments.args=c.array({c.array({v})})
 local bad=core:handle(assert(c.encode(request,{max_depth=d+5})))
 assert(bad.error or bad.result.structuredContent.error)
 print('PASS public_original_request_and_result_wrapper_depth_'..d)
end
