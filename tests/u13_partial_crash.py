"""Installed main manager-only death during a measured partial maximal bulk relay."""
from containment import enter
enter(120)
import json, os, select, signal, subprocess, time
from pathlib import Path
from u12_environment import CWD, PRELUDE
from deadlines import frame
from reap_oracle import identity, wait_disappeared

r,w=os.pipe()
bootstrap=PRELUDE+f'''
local x=require('lua_repl_mcp.worker_posix')
local g=require('lua_repl_mcp.guardian'); local new=g.new
local armed=false; local marked=false
local read=x.u.read
local barrier=assert(io.open('/proc/{os.getpid()}/fd/{w}','w'))
g.new=function(o)
 local b=new(o); local step=b.step
 x.u.read=function(fd,n)
  if marked and fd==b.channel.fd then return nil,'test blocked bulk',x.e.EAGAIN end
  return read(fd,n)
 end
 b.step=function(self,ms)
  step(self,ms)
  if armed and not marked and self.channel.input_bytes>65536 then
   marked=true; barrier:write('P'); barrier:flush()
  end
 end
 local execute=b.execute_owned
 b.execute_owned=function(self,...) armed=true; return execute(self,...) end
 return b
end
require('lua_repl_mcp.server').main()
'''
p=subprocess.Popen(['lua5.4','-e',bootstrap],cwd=CWD,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,bufsize=0)
serial=0

def send(method,params):
    global serial
    serial+=1
    p.stdin.write((json.dumps(dict(jsonrpc='2.0',id=serial,method=method,params=params))+'\n').encode())
    return serial

def rpc(method,params):
    expected=send(method,params)
    response=json.loads(frame(p.stdout,timeout=20))
    assert response['id']==expected,response
    return response['result']

try:
    rpc('initialize',dict(protocolVersion='2025-11-25',capabilities={},clientInfo=dict(name='partial-crash',version='1')))
    p.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
    session=rpc('tools/call',dict(name='session_create',arguments={}))['structuredContent']['session_id']
    guardian=int(Path(f'/proc/{p.pid}/task/{p.pid}/children').read_text().split()[0])
    worker=int(Path(f'/proc/{guardian}/task/{guardian}/children').read_text().split()[0])
    original=identity(worker)
    assert original and original[2]==guardian
    send('tools/call',dict(name='session_execute',arguments=dict(session_id=session,code='return string.rep("x",16777212)',wait_timeout_ms=None)))
    assert select.select([r],[],[],45)[0] and os.read(r,1)==b'P','partial relay barrier watchdog'
    # Endpoint is now withheld; full payload has not reached manager application.
    started=time.monotonic()
    p.kill(); assert p.wait(timeout=5)==-signal.SIGKILL
    wait_disappeared(worker,original,started+32)
    print('PASS installed_main_partial_maximum_bulk_manager_death_identity_disappeared seconds=%.3f'%(time.monotonic()-started),flush=True)
finally:
    if p.poll() is None: p.kill()
    p.wait(timeout=5)
    for stream in (p.stdin,p.stdout,p.stderr): stream.close()
    os.close(r); os.close(w)
