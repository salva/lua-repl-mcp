"""Configured installed stdio main: test-only constructor injection, no CLI options."""
from containment import enter
enter(180)
import json, subprocess, time, sys
from u12_environment import CWD, PRELUDE
from deadlines import frame
sys.setrecursionlimit(10000)
I,V,E,H=1500000,8192,128,1048576
W=I+V+6*E+H; R=I+3*W+H
for depth in (1,128,256,512):
    bootstrap=PRELUDE+f'''
local limits={{input_bytes={I},values_bytes={V},diagnostic_bytes={E},worker_bytes={W},response_bytes={R},output_bytes={R+1},max_depth={depth}}}
local g=require('lua_repl_mcp.guardian'); local new=g.new
g.new=function(o) o=o or {{}}; o.limits=limits; return new(o) end
local s=require('lua_repl_mcp.server'); local serve=s.serve
s.serve=function(io,o) o.limits=limits; return serve(io,o) end
s.main()
'''
    p=subprocess.Popen(['lua5.4','-e',bootstrap],cwd=CWD,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,bufsize=0)
    serial=0
    def request(method,params):
        global serial
        serial+=1
        body=json.dumps(dict(jsonrpc='2.0',id=serial,method=method,params=params),separators=(',',':'))
        return raw(body)
    def raw(body):
        p.stdin.write(body.encode()+b'\n'); p.stdin.flush()
        return json.loads(frame(p.stdout,timeout=45,maximum=R))
    def call(arguments):
        return request('tools/call',dict(name='session_execute',arguments=arguments))['result']['structuredContent']
    try:
        assert request('initialize',dict(protocolVersion='2025-11-25',capabilities={},clientInfo=dict(name='configured',version='1')))['id']==1
        p.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
        value=7
        for _ in range(depth): value=[value]
        code='local a=...; for i=1,'+str(depth)+' do a=a[1] end; return a'
        result=call(dict(code=code,args=[value],wait_timeout_ms=None))
        assert result.get('values')==[7],result
        result=call(dict(code='return ...',args=[value],wait_timeout_ms=None))
        assert result.get('values')==[value],result
        rejected=request('tools/call',dict(name='session_execute',arguments=dict(code='return 1',args=[[value]],wait_timeout_ms=None)))
        assert 'error' in rejected or rejected.get('result',{}).get('isError'),rejected
        if depth==128:
            for mode in ('escaped','numeric'):
                argument='"'+r'\u0001'*200000+'"' if mode=='escaped' else '['+','.join(['1e-7']*50001)+']'
                body='{"jsonrpc":"2.0","id":900,"method":"tools/call","params":{"name":"session_execute","arguments":{"code":"return type(...) , select(1,...)","args":['+argument+'],"wait_timeout_ms":null}}}'
                # Return only a small value; input token expansion is the tested boundary.
                body=body.replace('return type(...) , select(1,...)','return type(...)')
                assert len(body)<I
                body+=' '*(I-len(body))
                result=raw(body)['result']['structuredContent']
                assert result.get('values')==['string' if mode=='escaped' else 'table'],result
                print('PASS configured_stdio_exact_I_tight_floors',mode,I,W,R,R+1,flush=True)
        assert request('tools/call',dict(name='session_list',arguments={}))['result']
        print('PASS configured_stdio_depth_roundtrip_reject_next',depth,flush=True)
    finally:
        p.stdin.close()
        try: p.wait(timeout=35)
        except subprocess.TimeoutExpired: p.kill(); p.wait(); raise
        assert p.returncode==0,(p.returncode,p.stderr.read().decode(errors='replace'))
