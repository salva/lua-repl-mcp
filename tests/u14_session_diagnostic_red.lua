-- Independent regression: adapter/stopping can throw arbitrary Lua values.
-- Expected red at 98f26ef: final tostring invokes hostile __tostring unprotected.
local session=require('lua_repl_mcp.session')
local cases={'read','write','flush','stopping'}
local failures=0
for _,site in ipairs(cases) do
 local converted=0
 local thrown=setmetatable({},{__tostring=function() converted=converted+1; error('hostile diagnostic conversion') end})
 local io={read=function() return nil end,write=function(s) return #s end,flush=function() return true end}
 local options={allocation_generation=1,cwd='/'}
 if site=='stopping' then options.stopping=function() error(thrown) end
 else io[site]=function() error(thrown) end end
 local ok,out=pcall(session.serve,io,options)
 local expected=site=='stopping' and 'protocol_error' or 'transport_error'
 if not ok or type(out)~='table' or out.reason~=expected or converted~=0 then
  failures=failures+1
  print('FAIL '..site..' returns='..tostring(ok)..' diagnostic_metamethod_calls='..converted)
 end
end
assert(failures==0,'session must return local outcome without invoking arbitrary error metamethods; failures='..failures)
