-- Private result error contract: malformed records cannot complete execution.
local c=require('lua_repl_mcp.codec')
local p=require('lua_repl_mcp.worker_protocol')
local function base() return {code='lua_runtime_error',message='failure',stage='execution',execution_state='started'} end
local function frame(e)
 return assert(c.encode({protocol_version=1,type='result',allocation_generation=1,
  execution_generation=1,result={status='failed',error=e}}))
end
local function rejected(e) assert(not p.decode(frame(e)),'accepted malformed error') end
assert(p.decode(frame(base())))
for _,k in ipairs({'code','message','stage','execution_state'}) do
 local e=base(); e[k]=nil; rejected(e)
end
rejected({}); rejected(c.array({})); rejected(require('lua_repl_mcp').null)
for _,case in ipairs({{'code','invented'},{'message',false},{'stage','invented'},
 {'execution_state','invented'},{'traceback',1},{'path','not/a/pointer'},
 {'reason','invented'},{'data_preserved',1},{'truncated','yes'},
 {'invalid_bytes_escaped',0},{'exit_code',-1},{'exit_code',1.5},
 {'signal',0},{'signal',1.5},{'created_files',{}},{'created_files',c.array({1})},
 {'created_files_complete',1},{'process_exit_confirmed','yes'},{'unknown',true}}) do
 local e=base(); e[case[1]]=case[2]; rejected(e)
end
local e=base()
e.traceback='stack'; e.path='/a~1b'; e.reason='stdio_setup_failed'
e.data_preserved=false; e.truncated=true; e.invalid_bytes_escaped=true
e.exit_code=0; e.signal=9; e.created_files=c.array({'/tmp/out'})
e.created_files_complete=false; e.process_exit_confirmed=true
assert(p.decode(frame(e)))
-- Existing evaluator error shapes continue through the boundary unchanged.
local eval=require('lua_repl_mcp.evaluator')
for _,code in ipairs({'error("failure")','return function() end','local ='}) do
 local r=eval.execute({code=code,args=c.array({})})
 assert(r.error and p.decode(frame(r.error)))
end
print('PASS private_error_required_optional_types_enums_unknown_fields_and_evaluator_shapes')
