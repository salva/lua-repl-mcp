"""Real installed CLI maximum original bodies; external containment owns cleanup."""
from containment import enter
enter(240)
import json, os, subprocess, time
from u12_environment import CLI, CWD
from deadlines import frame
p=subprocess.Popen([str(CLI)],cwd=CWD,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,bufsize=0)
def send(text):
    p.stdin.write(text.encode()+b'\n'); p.stdin.flush()
def receive():
    return json.loads(frame(p.stdout,timeout=90,maximum=4*1024*1024))
try:
    send(json.dumps({'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2025-11-25','capabilities':{},'clientInfo':{'name':'batch2','version':'1'}}}))
    assert receive()['id']==1
    send('{"jsonrpc":"2.0","method":"notifications/initialized"}')
    for serial,mode in enumerate(os.environ.get('U13_ORIGINAL_MODES','escaped,numeric,surrogate').split(','),2):
        assert mode in ('escaped','numeric','surrogate')
        args=('"'+(r'\u0001' if mode=='escaped' else r'\ud83d\ude00')*200000+'"') if mode!='numeric' else '['+','.join(['1e-7']*800001)+']'
        text='{"jsonrpc":"2.0","id":'+str(serial)+',"method":"tools/call","params":{"name":"session_execute","arguments":{"code":"local a=...; return type(a)","args":['+args+'],"wait_timeout_ms":null}}}'
        # Complete original body exactly I, including legal trailing whitespace.
        I=16*1024*1024
        text=text+' '*(I-len(text))
        assert len(text)==I
        start=time.monotonic(); send(text); r=receive()
        value=r['result']['structuredContent']
        assert value.get('status')=='completed',value
        assert value['values']==['table' if mode=='numeric' else 'string']
        print('PASS installed_cli_exact_original_I',mode,'bytes',I,'seconds',round(time.monotonic()-start,3),flush=True)
    send('{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"session_list","arguments":{}}}')
    assert receive()['id']==9
finally:
    p.stdin.close()
    try: p.wait(timeout=40)
    except subprocess.TimeoutExpired: p.kill(); p.wait(); raise
    stderr=p.stderr.read().decode(errors='replace')
    assert p.returncode==0,(p.returncode,stderr)
