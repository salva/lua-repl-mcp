-- Pure decoder for the version-1 inherited-endpoint launch ABI.
local M={}
function M.decode(fd,generation,limits_json)
 local ok,result=pcall(function()
  assert(fd=='3','session FD must be 3')
  assert(type(generation)=='string' and #generation<=19 and generation:match('^[1-9][0-9]*$'),'invalid generation spelling')
  local g=tonumber(generation)
  assert(math.type(g)=='integer' and g>0,'invalid generation')
  assert(type(limits_json)=='string' and #limits_json<=4096,'invalid limits encoding')
  local c=require('lua_repl_mcp.codec')
  local limits=assert(c.decode(limits_json,{max_bytes=4096,max_depth=2}))
  assert(type(limits)=='table' and c.kind(limits)~='array','limits must be an object')
  local count=0; for _ in pairs(limits) do count=count+1 end
  assert(count==7,'all seven limits required')
  local validated=require('lua_repl_mcp.limits').connection(limits)
  return {fd=3,allocation_generation=g,limits=require('lua_repl_mcp.limits').authored(validated)}
 end)
 if ok then return result end
 return nil,tostring(result)
end
return M
