"""Measure exact-I public decoding, later controls and independent hard deadline."""
from containment import enter
enter(120)
import json, os, subprocess, time
from pathlib import Path
from u12_environment import CWD, PRELUDE
from deadlines import frame
from reap_oracle import identity, wait_disappeared
# Instrument the real parser checkpoint, without adding delay or skipping work.
r,w=os.pipe()
bootstrap=PRELUDE+f'''
local codec=require('lua_repl_mcp.codec'); local decode=codec.decode
local mark=assert(io.open('/proc/{os.getpid()}/fd/{w}','w'))
codec.decode=function(text,o)
 if #text==16777216 and o and o.checkpoint then
  local checkpoint=o.checkpoint; local sent=false
  local copy={{}}; for k,v in pairs(o) do copy[k]=v end
  copy.checkpoint=function()
   if not sent then sent=true; mark:write('P'); mark:flush() end
   return checkpoint()
  end
  local v,e=decode(text,copy); mark:write('D'); mark:flush(); return v,e
 end
 return decode(text,o)
end
require('lua_repl_mcp.server').main()
'''
p=subprocess.Popen(['lua5.4','-e',bootstrap],cwd=CWD,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,bufsize=0)
def send(text):
    data=text.encode()+b'\n'
    while data:
        n=p.stdin.write(data); assert n; data=data[n:]
def rpc(id,name,args):
    send(json.dumps(dict(jsonrpc='2.0',id=id,method='tools/call',params=dict(name=name,arguments=args))))
    value=json.loads(frame(p.stdout,timeout=30)); assert value['id']==id,value
    return value['result']['structuredContent']
try:
    send(json.dumps(dict(jsonrpc='2.0',id=1,method='initialize',params=dict(protocolVersion='2025-11-25',capabilities={},clientInfo=dict(name='decode-control',version='1')))))
    assert json.loads(frame(p.stdout,timeout=20))['id']==1
    send('{"jsonrpc":"2.0","method":"notifications/initialized"}')
    session=rpc(2,'session_create',{})['session_id']
    guardian=int(Path(f'/proc/{p.pid}/task/{p.pid}/children').read_text().split()[0])
    worker=int(Path(f'/proc/{guardian}/task/{guardian}/children').read_text().split()[0])
    original=identity(worker); assert original and original[2]==guardian
    rpc(3,'session_execute',dict(session_id=session,code='while true do end',execution_timeout_ms=500,wait_timeout_ms=0))
    # Worst measured numeric spelling, exact legal I including trailing space.
    text='{"jsonrpc":"2.0","id":4,"method":"ping","extra":['+','.join(['1e-7']*800001)+']}'
    text+=' '*(16777216-len(text)); assert len(text)==16777216
    started=time.monotonic(); send(text)
    import select
    assert select.select([r],[],[],20)[0] and os.read(r,1)==b'P','decode checkpoint watchdog'
    # Later complete controls remain in wire order, not classified from partial JSON.
    send(json.dumps(dict(jsonrpc='2.0',id=5,method='tools/call',params=dict(name='session_list',arguments={}))))
    wait_disappeared(worker,original,started+32)
    reaped=time.monotonic()-started
    for id in (4,5):
        value=json.loads(frame(p.stdout,timeout=30)); assert value['id']==id,value
    elapsed=time.monotonic()-started
    assert select.select([r],[],[],1)[0] and os.read(r,1)==b'D'
    # Dead allocation still accepts explicit cleanup and reports truthfully.
    killed=rpc(6,'session_kill',dict(session_id=session)); assert killed.get('process_exit_confirmed') or killed.get('error',{}).get('code')=='unknown_session',killed
    p.stdin.close(); assert p.wait(timeout=35)==0,p.stderr.read()
    print('PASS installed_exact_I_decode_later_list_kill_original_deadline_reap bytes=16777216 elapsed=%.3f reaped=%.3f'%(elapsed,reaped),flush=True)
finally:
    if p.poll() is None: p.kill()
    p.wait(timeout=5)
    for stream in (p.stdin,p.stdout,p.stderr): stream.close()
    os.close(r); os.close(w)
