"""Run the authored embedding options example through the pure handler."""
from pathlib import Path
import re
import subprocess
page=Path('site-docs/embedding.md').read_text()
snippet=re.findall(r'```lua\n(.*?)\n```',page,re.S)
assert len(snippet)==1
prefix='''
local codec=require('lua_repl_mcp.codec')
local handler=require('lua_repl_mcp.handler')
local frames={
 {jsonrpc='2.0',id=1,method='initialize',params={protocolVersion='2025-11-25',capabilities={},clientInfo={name='options-doc',version='1'}}},
 {jsonrpc='2.0',method='notifications/initialized'},
 {jsonrpc='2.0',id=2,method='tools/call',params={name='repl_execute',arguments={code='return 42'}}},
 {jsonrpc='2.0',id=3,method='tools/call',params={name='repl_close',arguments={}}},
}
local input=''
for _,f in ipairs(frames) do input=input..assert(codec.encode(f))..'\\n' end
local output=''
local adapter={
 read=function(n) if #input==0 then return nil,'eof' end local s=input:sub(1,n); input=input:sub(n+1); return s end,
 write=function(s) output=output..s; return #s end,
 flush=function() return true end,
}
'''
suffix='''
assert(attachment.reason=='close_requested' and attachment.acknowledgement_sent)
local found=false
for line in output:gmatch('[^\\n]+') do
 local r=assert(codec.decode(line))
 if r.id==2 then assert(r.result.structuredContent.values[1]==42); found=true end
end
assert(found)
local touched=false
local invalid=handler.serve({read=function() touched=true end}, {evaluator={diagnostic_bytes=48}})
assert(invalid.reason=='handler_error' and not touched)
assert(invalid.diagnostics:find('diagnostic limit cannot hold loss notice',1,true))
local limits=require('lua_repl_mcp.limits')
assert(#require('lua_repl_mcp.errors').notice==49)
local defaults=limits.evaluator()
assert(defaults.max_bytes==16777216 and defaults.max_depth==128 and defaults.diagnostic_bytes==65536)
for name in pairs(package.loaded) do assert(not name:match('^posix') and name~='lua_repl_mcp.manager' and name~='lua_repl_mcp.server') end
print('PASS: authored embedding options initialize/execute/close; invalid minimum before I/O; defaults; native-free')
'''
subprocess.run(['lua5.4','-'],input=prefix+snippet[0]+suffix,text=True,check=True)
