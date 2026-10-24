-- Borrowed-I/O, same-state, partial writes and buffered stop regression.
package.preload['posix.unistd']=function() error('native dependency imported') end
local c=require('lua_repl_mcp.codec')
local p=require('lua_repl_mcp.worker_protocol')
local session=require('lua_repl_mcp.session')
local limits=require('lua_repl_mcp.limits').connection()
local authored=require('lua_repl_mcp.limits').authored(limits)
local b=assert(require('lua_repl_mcp.bootstrap').decode('3','1',assert(c.encode(authored))))
assert(b.fd==3)
assert(not require('lua_repl_mcp.bootstrap').decode('4','1','{}'))
assert(not require('lua_repl_mcp.bootstrap').decode('3','01',assert(c.encode(authored))))
local function record(kind,extra) return assert(p.encode(p.record(kind,1,extra),limits)) end
local input=record('execute',{execution_generation=1,input={code='u14_count=(u14_count or 0)+1; return u14_count'}})..record('execute',{execution_generation=2,input={code='u14_count=u14_count+1; return u14_count'}})..record('close')
local output=''; local flushes=0
local result=session.serve({read=function(n) local chunk=input:sub(1,n); input=input:sub(#chunk+1); return #chunk>0 and chunk or nil end,
 write=function(text) output=output..text:sub(1,3); return math.min(3,#text) end,
 flush=function() flushes=flushes+1; return true end,
 close=function() error('borrowed close') end},
 {allocation_generation=1,cwd='/host',limits=authored,stopping=function() return flushes==2 end})
assert(result.reason=='host_stopping',result.diagnostics)
assert(u14_count==1 and flushes==2)
local records={}; for line in output:gmatch('[^\n]+') do records[#records+1]=assert(p.decode(line,limits)) end
assert(#records==2 and records[1].type=='ready' and records[2].result.values[1]==1)
assert(session.serve({read=function() return nil end,write=function(s) return #s end,flush=function() return true end},{allocation_generation=1,cwd='/host',limits=authored}).reason=='eof')
assert(session.serve({read=function() error('bad read') end,write=function(s) return #s end,flush=function() return true end},{allocation_generation=1,cwd='/host',limits=authored}).reason=='transport_error')
print('PASS pure session/bootstrap, same-state once-only, partial writes, buffered stopping and borrowed ownership')
