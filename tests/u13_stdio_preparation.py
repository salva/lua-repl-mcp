"""Installed stdio controls at the actual post-decode, pre-admission checkpoint."""
from containment import enter
enter(120)
import json, os, select, subprocess
from u12_environment import CWD, PRELUDE
from deadlines import frame
r,w=os.pipe()
bootstrap=PRELUDE+f'''
local m=require('lua_repl_mcp.manager'); local new=m.new
local barrier=assert(io.open('/proc/{os.getpid()}/fd/{w}','w'))
m.new=function(o)
 local b=new(o); local accept=b.accept; local marked=false
 b.accept=function(self,tool,args,id,original,checkpoint,only)
  if id==90 and not marked then
   assert(tool=='session_execute' and checkpoint and original)
   return accept(self,tool,args,id,original,function()
    assert(not self.requests[id] and self.slots.ordinary==0)
    if not marked then marked=true; barrier:write('P'); barrier:flush() end
    -- Deliberately hold only this already yielding preparation. Client cancel
    -- must destroy it, not release the gate or allocate an implicit session.
    while true do checkpoint() end
   end,only)
  end
  return accept(self,tool,args,id,original,checkpoint,only)
 end
 return b
end
require('lua_repl_mcp.server').main()
'''
p=subprocess.Popen(['lua5.4','-e',bootstrap],cwd=CWD,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,bufsize=0)
def send(id,method,params=None):
    obj=dict(jsonrpc='2.0',method=method)
    if id is not None: obj['id']=id
    if params is not None: obj['params']=params
    data=(json.dumps(obj,separators=(',',':'))+'\n').encode()
    # FileIO can short-write large frames.
    while data:
        n=p.stdin.write(data); assert n; data=data[n:]
def receive(id):
    v=json.loads(frame(p.stdout,timeout=25)); assert v['id']==id,v
    return v
def call(id,name,args):
    send(id,'tools/call',dict(name=name,arguments=args))
    return receive(id)['result']['structuredContent']
try:
    send(1,'initialize',dict(protocolVersion='2025-11-25',capabilities={},clientInfo=dict(name='preparation',version='1'))); receive(1)
    send(None,'notifications/initialized')
    session=call(2,'session_create',{})['session_id']
    send(90,'tools/call',dict(name='session_execute',arguments=dict(code='return 99',args=[[1]*150000],wait_timeout_ms=0)))
    assert select.select([r],[],[],25)[0] and os.read(r,1)==b'P','pre-admission barrier watchdog'
    listing=call(3,'session_list',{})
    assert len(listing['sessions'])==1,listing
    # Duplicate is rejected while the unfinished transport owns this ID.
    send(90,'ping'); assert receive(None)['error']['code']==-32600
    killed=call(4,'session_kill',dict(session_id=session))
    assert killed['process_exit_confirmed'],killed
    send(None,'notifications/cancelled',dict(requestId=90))
    send(None,'notifications/cancelled',dict(requestId=90))
    # Reuse only after cancellation; held preparation cannot ever allocate.
    value=call(90,'session_execute',dict(code='return 73'))
    assert value.get('values')==[73],value
    replacement=value['session_id']
    listing=call(5,'session_list',{})
    assert len(listing['sessions'])==1 and listing['sessions'][0]['session_id']==replacement,listing
    assert call(6,'session_kill',dict(session_id=replacement))['process_exit_confirmed']
    p.stdin.close(); assert p.wait(timeout=35)==0,p.stderr.read()
    print('PASS installed_stdio_pre_admission_list_duplicate_kill_cancel_reuse_no_stale_dispatch',flush=True)
finally:
    if p.poll() is None: p.kill()
    p.wait(timeout=5)
    for stream in (p.stdin,p.stdout,p.stderr): stream.close()
    os.close(r); os.close(w)
