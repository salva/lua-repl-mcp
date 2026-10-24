"""Direct private-wire native host tests: buffered stop and blocked read wakeup.
Run with installation-only LUA_PATH and U14_NATIVE_HOST pointing to built C host.
"""
from containment import enter
enter(30)
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile

host=os.environ['U14_NATIVE_HOST']
script=str(Path(__file__).with_name('u14_native_host.lua').resolve())
limits=dict(input_bytes=16777216,values_bytes=16777216,diagnostic_bytes=65536,
            max_depth=128,worker_bytes=67108864,response_bytes=134217728,output_bytes=268435456)
def record(kind, **kw):
    return (json.dumps(dict(type=kind, protocol_version=1, allocation_generation=1, **kw))+'\n').encode()

def run(mode, directory):
    a,b=socket.socketpair()
    # Preserve both through Popen close_fds; child remap runs after that close.
    def setup():
        os.dup2(b.fileno(),3,inheritable=True)
    env=dict(os.environ, LUA_REPL_MCP_SESSION_FD='3', LUA_REPL_MCP_ALLOCATION_GENERATION='1',
             LUA_REPL_MCP_LIMITS=json.dumps(limits))
    p=subprocess.Popen([host,script],env=env,pass_fds=tuple({a.fileno(),b.fileno(),3}),preexec_fn=setup,
                       stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    b.close(); a.settimeout(4)
    f=a.makefile('rb')
    receipt=str(Path(directory)/mode)
    try:
        assert json.loads(f.readline())['type']=='ready'
        code='host_receipt=...;host_value=77;'+('host_stopping=true;' if mode=='stop' else '')+'return host_value'
        message=record('execute',execution_generation=1,input=dict(code=code,args=[receipt]))
        # Send multiple commands in one write: later effect must never run.
        if mode in ('stop','close'):
            message+=(record('close') if mode=='close' else b'')
            message+=record('execute',execution_generation=2,input=dict(code='host_value=999'))
        a.sendall(message)
        assert json.loads(f.readline())['result']['values']==[77]
        if mode=='eof':
            assert p.poll() is None  # serve is blocked in borrowed native read
            a.shutdown(socket.SHUT_WR)  # host-arranged wakeup, no premature close
        assert p.wait(timeout=4)==0,p.stderr.read()
        expected={'stop':'host_stopping','close':'closed','eof':'eof'}[mode]
        assert Path(receipt).read_text()==expected+':77'
        try:
            assert f.readline()==b''
        except ConnectionResetError:
            # Closing a stream with unread later commands may reset the peer.
            assert mode in ('stop','close')
    finally:
        f.close();a.close()
        if p.poll() is None: p.kill();p.wait()

work=Path(os.environ['SAIVAGE_CARD_WORK_ROOT'])/'u14-wire'
work.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(dir=work) as d:
    for mode in ('stop','close','eof'): run(mode,d)
print('PASS native buffered stop/close rejects later effects, borrowed blocked read EOF wakeup and host continuation')
