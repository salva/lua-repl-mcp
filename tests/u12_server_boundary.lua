-- Protected initialization/loop/cleanup error ordering, no native ownership.
local server=require('lua_repl_mcp.server')
local manager=require('lua_repl_mcp.manager')
local transport=require('lua_repl_mcp.client_transport')
local mn,tn=manager.new,transport.new
for _,point in ipairs{'transport_init','loop','cleanup'} do
 local cleaned=0
 manager.new=function() return {disconnect=function() cleaned=cleaned+1; error('secondary cleanup') end} end
 transport.new=function(m)
  if point=='transport_init' then error('original transport construction') end
  return {step=function() if point=='loop' then error('original loop') end; return false end,
   close=function() cleaned=cleaned+1; error('secondary cleanup') end}
 end
 local ok,err=pcall(server.serve,{})
 assert(not ok and cleaned==1)
 if point=='cleanup' then assert(tostring(err):find('secondary cleanup',1,true))
 else assert(tostring(err):find('original',1,true) and not tostring(err):find('secondary',1,true)) end
 print('PASS protected_server_'..point..'_original_failure_order')
end
manager.new=mn; transport.new=tn
