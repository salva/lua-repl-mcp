-- Pure Lua runtime tests. No installed Lua modules or native loaders available.
package.path=os.getenv('U9_INSTALLED_LUA_PATH') or './?.lua;./?/init.lua'
package.cpath=''
package.searchers={package.searchers[1],package.searchers[2]}
local codec=require('lua_repl_mcp.codec')
local contracts=require('lua_repl_mcp.contracts')
local eval=require('lua_repl_mcp.evaluator')
local errors=require('lua_repl_mcp.errors')
local null=require('lua_repl_mcp').null
local count=0
local function test(name,f)
  f(); count=count+1; print('PASS '..name)
end
local function equal(a,b) assert(a==b,('expected %s; got %s'):format(tostring(b),tostring(a))) end
local function execute(code,args,options)
  local input={code=code}
  if args then input.args=args end
  return eval.execute(input,options)
end
local function failed(code,expected,args,options)
  local r=execute(code,args,options)
  equal(r.status,'failed'); equal(r.error.code,expected); equal(r.values,nil)
  return r.error
end
local function decode(s) local v,e=codec.decode(s); assert(v~=nil,e and e.reason); return v end
local function reject(s) local v,e=codec.decode(s); assert(v==nil and e.reason,s) end
local function encoded(v,expected) local s,e=codec.encode(v); assert(s,e and e.reason); equal(s,expected) end

test('numeric_lexical_safe_boundaries',function()
  for _,s in ipairs({'9007199254740991','-9007199254740991','9007199254740991.0','9.007199254740991e15','90071992547409910e-1','0e9999999999999999999'}) do decode(s) end
  for _,s in ipairs({'9007199254740992','9007199254740993','-9007199254740992','9007199254740992.0','9007199254740993.0','9.007199254740993e15','-9.007199254740993e15','90071992547409930e-1','900719925474099100e0','1e10000000000','9007199254740991.9'}) do reject(s) end
  for _,s in ipairs({'0.1','1.5','-1.25','1e-99999999999','0.00001e5'}) do decode(s) end
end)
test('strict_json_grammar_unicode',function()
  for _,s in ipairs({'','01','-01','+1','.1','1.','1e','1e+','NaN','Infinity','true false','[1,]','{"a":1,}','{"a":1,"a":2}','"\\uD800"','"\\uDC00"','"\\uD800\\u0000"','"\\x01"','"\255"','"\192\128"','"\237\160\128"','"\n"','[','{"a" 1}'}) do reject(s) end
  equal(decode('"\\uD83D\\uDE00"'),'😀')
  equal(decode('"\\u0000\\n\\t\\\\\\\""'),'\0\n\t\\"')
  encoded(decode('[null,{"x":null},[]]'),'[null,{"x":null},[]]')
end)
test('all_seven_contract_defaults_and_rejection',function()
  for _,name in ipairs({'session_create','session_list','repl_close'}) do assert(contracts.from_json(name,'{}')) end
  local r=assert(contracts.from_json('session_execute','{"code":""}'))
  equal(r.session_id,null); equal(r.execution_timeout_ms,null); equal(r.wait_timeout_ms,600000); equal(codec.kind(r.args),'array')
  r=assert(contracts.from_json('session_wait','{"session_id":"s"}')); equal(r.wait_timeout_ms,600000)
  assert(contracts.from_json('session_kill','{"session_id":"s"}'))
  assert(contracts.from_json('repl_execute','{"code":""}'))
  for _,name in ipairs({'session_create','session_execute','session_wait','session_kill','session_list','repl_execute','repl_close'}) do
    local v,e=contracts.from_json(name,'{"extra":1}'); assert(not v); equal(e.code,'invalid_arguments'); equal(e.execution_state,'not_started')
    assert(not contracts.from_json(name,'[]'))
    assert(not contracts.from_json(name,'null'))
  end
  local bad={
    {'repl_execute','{}'}, {'repl_execute','{"code":null}'}, {'repl_execute','{"code":"","session_id":null}'},
    {'repl_execute','{"code":"","args":{}}'}, {'repl_execute','{"code":"","args":null}'},
    {'session_execute','{"code":"","session_id":""}'},
    {'session_execute','{"code":"","session_id":"s","create_options":{}}'},
    {'session_execute','{"code":"","create_options":{"cwd":""}}'},
    {'session_execute','{"code":"","create_options":{"oops":1}}'},
    {'session_create','{"cwd":null}'}, {'session_create','{"stdout_path":""}'},
    {'session_wait','{}'}, {'session_wait','{"session_id":null}'}, {'session_kill','{"session_id":""}'},
    {'session_wait','{"session_id":"s","wait_timeout_ms":-1}'},
    {'session_execute','{"code":"","execution_timeout_ms":0}'},
    {'session_execute','{"code":"","wait_timeout_ms":2147483648}'},
    {'session_execute','{"code":"","execution_timeout_ms":1.5}'}
  }
  for _,case in ipairs(bad) do local v,e=contracts.from_json(case[1],case[2]); assert(not v,case[2]); assert(e.path) end
  for _,wait in ipairs({'null','0','1','2147483647'}) do
    assert(contracts.from_json('session_wait','{"session_id":"s","wait_timeout_ms":'..wait..'}'))
  end
  for _,hard in ipairs({'null','1','2147483647'}) do
    assert(contracts.from_json('session_execute','{"code":"","execution_timeout_ms":'..hard..'}'))
  end
  assert(contracts.from_json('session_execute','{"code":"","create_options":{"cwd":".","stdin_path":"in","stdout_path":"out","stderr_path":"out"}}'))
end)
test('persistent_globals_functions_chunk_locals',function()
  equal(execute('u1_counter=40; function u1_add(x) u1_counter=u1_counter+x; return u1_counter end; local u1_local=99').status,'completed')
  local r=execute('return u1_add(2),u1_local'); equal(r.values[1],42); equal(r.values[2],null)
end)
test('explicit_return_count_and_nil_positions',function()
  encoded(execute('').values,'[]')
  encoded(execute('return nil').values,'[null]')
  encoded(execute('return nil,2,nil,nil').values,'[null,2,null,null]')
  failed('1+1','lua_syntax_error')
  encoded(execute('local x=1+1').values,'[]')
end)
test('null_varargs_fresh_tables_and_empty_mapping',function()
  local args=decode('[null,{"x":null},[],"hi"]')
  encoded(execute('local a,b,c,d=...; return select("#",...),a,b,c,d,a==require("lua_repl_mcp").null',args).values,'[4,null,{"x":null},{},"hi",true]')
  execute('local a,b=...; b.x=3; u1_saved=b',args)
  encoded(execute('local a,b=...; return b.x,u1_saved==b',args).values,'[null,false]')
  equal(args[2].x,null)
end)
test('errors_recover_side_effects_once',function()
  execute('u1_side=0')
  local e=failed('u1_side=u1_side+1; error("oops")','lua_runtime_error')
  equal(e.execution_state,'started'); assert(e.traceback:find('stack traceback',1,true))
  failed('u1_side=u1_side+1; return function() end','result_serialization_error')
  failed('u1_side=u1_side+1; ???','lua_syntax_error')
  encoded(execute('return u1_side').values,'[2]')
end)
test('unsupported_returns_and_shapes_no_partial_values',function()
  for _,code in ipairs({
    'return 1,function()end', 'return io.stdout', 'return coroutine.create(function()end)',
    'local t={}; t.self=t; return t', 'return {[1]=1,[3]=3}', 'return {[1]=1,x=2}',
    'return {[false]=1}', 'return {[{}]=1}', 'return 0/0','return 1/0','return -1/0',
    'return "\\255"','return {x="\\192\\128"}', 'return 9007199254740992',
    'return 9007199254740992.0','return 1e20'
  }) do
    local e=failed(code,'result_serialization_error'); equal(e.execution_state,'completed'); assert(e.message:find('side effects',1,true))
  end
  encoded(execute('return 9007199254740991,-9007199254740991,1.5').values,'[9007199254740991,-9007199254740991,1.5]')
  encoded(execute('local x={a=1}; return x,x').values,'[{"a":1},{"a":1}]')
end)
test('hostile_metamethods_and_arbitrary_thrown_values',function()
  execute('u1_meta=0; u1_mt={__pairs=function() u1_meta=u1_meta+1; error("pairs") end, __index=function() u1_meta=u1_meta+1; error("index") end, __len=function() u1_meta=u1_meta+1; error("len") end, __tostring=function() u1_meta=u1_meta+1; error("tostring") end, __eq=function() u1_meta=u1_meta+1; error("eq") end}')
  encoded(execute('return setmetatable({x=1},u1_mt),setmetatable({},u1_mt)').values,'[{"x":1},{}]')
  local e=failed('error(setmetatable({},u1_mt))','lua_runtime_error'); equal(e.message,'<table error value>')
  for _,v in ipairs({'nil','false','42','function()end','io.stdout','coroutine.create(function()end)'}) do failed('error('..v..')','lua_runtime_error') end
  encoded(execute('return u1_meta').values,'[0]')
end)
test('rfc6901_pointers',function()
  equal(failed('return { ["a/b~c"]={false,function()end} }','result_serialization_error').path,'/values/0/a~1b~0c/1')
  local v,e=contracts.from_json('repl_execute','{"code":"","a/b~c":1}'); assert(not v); equal(e.path,'/a~1b~0c')
  local v2,e2=codec.decode('{"args":[{"a/b~c":9007199254740993.0}]}'); assert(not v2); equal(e2.path,'/args/0/a~1b~0c')
end)
test('bounds_encoded_bytes_depth_and_diagnostics',function()
  local r=execute('return "\\0"',nil,{max_bytes=10}); equal(r.status,'completed') -- ["\u0000"] is ten bytes
  failed('return "\\0"','result_serialization_error',nil,{max_bytes=9})
  failed('return','result_serialization_error',nil,{max_bytes=1})
  equal(execute('return {x={}}',nil,{max_depth=2}).status,'completed')
  failed('return {x={x={}}}','result_serialization_error',nil,{max_depth=2})
  local v,e=codec.decode('[[[]]]',{max_depth=2}); assert(not v); assert(e.reason:find('nesting'))
  assert(not codec.decode('123',{max_bytes=2}))
  local err=errors.new('lua_runtime_error','bad\255😀','execution','started',{traceback='x\254'},128)
  equal(err.data_preserved,false); equal(err.invalid_bytes_escaped,true); assert(err.message:find('\\xFF',1,true)); assert(err.traceback:find('\\xFE',1,true))
  assert(codec.encode(err))
  err=errors.new('lua_runtime_error',string.rep('😀',100),'execution','started',{traceback=string.rep('x',100)},80)
  equal(err.truncated,true); equal(err.data_preserved,false); assert(#err.message+#(err.traceback or '')<=80); assert(codec.valid_utf8(err.message)); assert(err.message:find(errors.notice,1,true))
  err=errors.new('x','hello','execution','started',{traceback='world'},80)
  equal(err.data_preserved,nil); equal(err.message,'hello'); equal(err.traceback,'world')
end)
test('output_functions_untouched_and_explicit_capture',function()
  local p,w=print,io.write
  local r=execute('local b={}; local function capture(x) b[#b+1]=x end; capture("hello"); return table.concat(b)')
  encoded(r.values,'["hello"]'); equal(print,p); equal(io.write,w); equal(r.output,nil)
end)
test('operator_limits_and_hostile_argument_keys',function()
  for _,options in ipairs({{max_bytes=0},{max_depth=-1},{diagnostic_bytes=1},{max_depth=1.5},{unknown=1}}) do
    assert(not pcall(eval.execute,{code=''},options))
  end
  local calls=0
  local key=setmetatable({},{__tostring=function() calls=calls+1; error('unsafe') end})
  local v,e=contracts.validate('repl_execute',{code='', [key]=1})
  assert(not v); equal(e.path,''); equal(calls,0)
  local args=codec.array({setmetatable({x=1},{__pairs=function() calls=calls+1; error('unsafe') end})})
  encoded(execute('return ...',args).values,'[{"x":1}]'); equal(calls,0)
end)
test('default_depth_and_byte_boundaries',function()
  local function nested(n) return string.rep('[',n)..'0'..string.rep(']',n) end
  assert(codec.decode(nested(128))); assert(not codec.decode(nested(129)))
  local big=string.rep('a',16*1024*1024-2)
  assert(codec.decode('"'..big..'"')); assert(not codec.decode('"'..big..'a"'))
  assert(codec.encode(big)); assert(not codec.encode(big..'a'))
  local err=errors.new('x',string.rep('x',65537),'execution','started')
  equal(#err.message,65536); equal(err.truncated,true)
end)
print(('PASS %d U1 groups'):format(count))
