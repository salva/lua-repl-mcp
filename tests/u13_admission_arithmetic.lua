local L=require('lua_repl_mcp.limits')
assert(L.admission().sessions==64)
for _,o in ipairs{{sessions=math.maxinteger},{sessions=357913942},{ordinary=2147483647},{control=2147483647},{kill_reserve=2147483647,control=2147483647}} do
 assert(not pcall(L.admission,o),'overflow accepted')
end
assert(L.admission{sessions=357913941}.sessions==357913941)
print('PASS aggregate_admission_arithmetic_before_backend')
