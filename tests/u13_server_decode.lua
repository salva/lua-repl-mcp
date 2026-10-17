-- Actual server owner: strict decoding yields, preserves order, advances timers.
local server=require('lua_repl_mcp.server')
local manager=require('lua_repl_mcp.manager')
local codec=require('lua_repl_mcp.codec')
local old=manager.new
local ticks=0
manager.new=function()
 return {limits={max_depth=128,input_bytes=16777216,response_bytes=134217728,output_bytes=268435456},
 step=function() ticks=ticks+1 end,requests={},disconnect=function() end}
end
local large='{"jsonrpc":"2.0","id":1,"method":"ping","extra":"'..string.rep('a',262144)..'"}'
local wire=large..'\n{"jsonrpc":"2.0","id":2,"method":"ping"}\n'
local pos,output=1,''
local at={}
local ok,e=pcall(server.serve,{
 read=function(n)
  if pos>#wire then return nil,'again' end
  local part=wire:sub(pos,pos+n-1); pos=pos+#part; return part
 end,
 write=function(s)
  output=output..s; at[#at+1]=ticks; return #s
 end,
 stopping=function() return output:find('"id":2',1,true)~=nil end,
})
manager.new=old; assert(ok,e)
local first,second=output:match('([^\n]+)\n([^\n]+)\n')
assert(codec.decode(first).id==1 and codec.decode(second).id==2)
-- Four framing reads alone are not parser progress; strict decode requires
-- additional worker turns before the first response can be published.
assert(at[1]>=8,'strict full frame decode blocked a transport turn')
print('PASS server_strict_decode_slices_order_timers ticks='..ticks)
