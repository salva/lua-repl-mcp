-- Native custom-host descriptor/setup/startup matrix. Run under containment.
local x=require('lua_repl_mcp.worker_posix')
local codec=require('lua_repl_mcp.codec')
local native=require('lua_repl_mcp.worker_supervisor')
local host,script,work=assert(arg[1]),assert(arg[2]),assert(arg[3])
local function run(mask)
 local s=native.new{startup_timeout_ms=150}
 -- All closed-standard combinations; restore only in the parent after fork.
 local saved={}
 for fd=0,2 do if mask & (1<<fd) ~=0 then
  saved[fd]=assert(x.f.fcntl(fd,x.f.F_DUPFD,20)); x.u.close(fd)
 end end
 local w=s:allocate{command=codec.array{host,script}}
 local function until_(f)
  local end_=x.now()+4
  repeat s:step(2); if f() then return end until x.now()>end_
  error('matrix deadline mask '..mask)
 end
 until_(function() return w.state~='starting' end)
 assert(w.state=='idle','mask '..mask..' '..tostring(w.failure)..' '..tostring(w.startup_message))
 assert(s:execute(w,{code='return host_api(5),host_cwd'}))
 until_(function() return w.state~='running' end)
 assert(w.result.values[1]==105)
 assert(s:graceful_close(w))
 until_(function() return w.state=='dead' end)
 assert(w.process_exit_confirmed and not w.failure,tostring(w.failure))
 assert(s:shutdown())
 for fd,copy in pairs(saved) do assert(x.u.dup2(copy,fd)); x.u.close(copy) end
end
for mask=0,7 do run(mask) end
local s=native.new{startup_timeout_ms=50}
local function failure(options,reason)
 local w=s:allocate(options)
 local stop=x.now()+4
 repeat s:step(2) until w.state=='dead' or x.now()>stop
 assert(w.state=='dead' and w.process_exit_confirmed)
 assert(w.failure==reason or (reason=='invalid_ready' and (w.failure=='handshake_failed' or w.failure=='corrupt_worker')),tostring(w.failure)..' expected '..reason..' command '..table.concat(options.command or {},' '))
 return w
end
failure({command=codec.array{work..'/absent'}},'spawn_failed')
failure({command=codec.array{host,script},cwd=work..'/absent'},'cwd_setup_failed')
failure({command=codec.array{host,script},stdout_path=work..'/absent/output'},'stdio_setup_failed')
failure({command=codec.array{'/bin/sleep','1'}},'startup_timeout')
local variant=script:sub(1,-#'u14_native_host.lua'-1)..'u14_native_readiness_host.lua'
for _,mode in ipairs{'malformed','version','generation','late'} do
 failure({command=codec.array{host,variant,mode}},mode=='late' and 'startup_timeout' or 'invalid_ready')
end
-- A receipt emitted before a later setup failure must remain truthful.
local output=work..'/partial-native-receipt'
os.remove(output)
local partial=failure({command=codec.array{host,script},stdout_path=output,stdin_path=work..'/absent/input'},'stdio_setup_failed')
assert(#partial.created_paths==1 and partial.created_paths[1]==output and not partial.files_complete)
assert(io.open(output,'r')):close()
assert(s:shutdown())
print('PASS native all eight closed-stdio collision masks, graceful borrowed return, exec/cwd/stdio failures, initialization timeout with exact reap')
