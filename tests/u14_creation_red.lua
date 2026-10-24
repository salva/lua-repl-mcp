-- U14 ingress acceptance probe: lua5.4 tests/u14_creation_red.lua
local c=require('lua_repl_mcp.codec')
local contracts=require('lua_repl_mcp.contracts')
local protocol=require('lua_repl_mcp.worker_protocol')
local limits=require('lua_repl_mcp.limits').connection()
local failures=0
local function check(name,ok,err)
 print((ok and 'PASS ' or 'FAIL ')..name..(err and (' '..err.code..' '..tostring(err.path)) or ''))
 if not ok then failures=failures+1 end
end
local cases={
 {'default explicit','session_create','{}',true},
 {'default implicit','session_execute','{"code":"return 1"}',true},
 {'literal argv explicit','session_create','{"command":["host","a b","$HOME",""]}',true},
 {'literal argv implicit','session_execute','{"code":"return 1","create_options":{"command":["host",""]}}',true},
 {'empty argv','session_create','{"command":[]}',false},
 {'empty executable','session_create','{"command":[""]}',false},
 {'NUL argv','session_create','{"command":["host","a\\u0000b"]}',false},
 {'nonstring argv','session_create','{"command":["host",1]}',false},
}
for _,case in ipairs(cases) do
 local name,tool,text,expected=table.unpack(case)
 local value,err=contracts.from_json(tool,text)
 check(name,(value~=nil)==expected,err)
 if expected and name:find('literal') then
  local body=assert(c.json_data('{"jsonrpc":"2.0","method":"tools/call","params":{"name":"'..tool..'","arguments":'..text..'}}'))
  check(name..' immutable ingress',protocol.creation_arguments(body,limits)~=nil)
 end
end
print('managed custom-host ingress failures='..failures)
os.exit(failures==0 and 0 or 1)
