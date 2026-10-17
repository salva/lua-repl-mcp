"""Human/LLM documentation examples against clean-installed manager discovery."""
import json, os, pathlib, re, select, subprocess, time
from jsonschema import Draft202012Validator
ROOT=pathlib.Path(__file__).resolve().parents[1]
W=pathlib.Path(os.environ['SAIVAGE_CARD_WORK_ROOT'])/'u11-installed'
tree=W/'rocks'; outside=W/'outside';outside.mkdir(exist_ok=True)
env=os.environ.copy()
for k in ['LUA_PATH_5_4','LUA_CPATH_5_4']:env.pop(k,None)
env['LUA_PATH']=f'{tree}/share/lua/5.4/?.lua;{tree}/share/lua/5.4/?/init.lua'
env['LUA_CPATH']=f'{tree}/lib/lua/5.4/?.so'
for src in (ROOT/'lua_repl_mcp').glob('*.lua'):
    assert src.read_bytes()==(tree/'share/lua/5.4/lua_repl_mcp'/src.name).read_bytes()
print('PASS installed module byte identity; outside cwd; installation-only paths')
for guide in ['site-docs/getting-started.md','README-IF-YOR-ARE-AN-AI.md']:
    p=subprocess.Popen([str(tree/'bin/lua-repl-mcp')],cwd=outside,env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,bufsize=0)
    pending=b''; seq=0
    def rpc(method,params):
        global seq,pending
        seq+=1;p.stdin.write((json.dumps(dict(jsonrpc='2.0',id=seq,method=method,params=params))+'\n').encode())
        deadline=time.monotonic()+8
        while b'\n' not in pending:
            assert select.select([p.stdout],[],[],max(0,deadline-time.monotonic()))[0], 'watchdog'
            chunk=os.read(p.stdout.fileno(),65536);assert chunk,'EOF';pending+=chunk
        line,pending=pending.split(b'\n',1);r=json.loads(line);assert r['id']==seq,r
        return r['result']
    try:
        assert rpc('initialize',dict(protocolVersion='2025-11-25',capabilities={},clientInfo=dict(name='website-consumer',version='1')))['protocolVersion']=='2025-11-25'
        p.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
        tools={t['name']:t for t in rpc('tools/list',{})['tools']}
        assert set(tools)==set('session_create session_list session_execute session_wait session_kill'.split())
        def call(name,args):
            Draft202012Validator(tools[name]['inputSchema']).validate(args)
            r=rpc('tools/call',dict(name=name,arguments=args));v=r['structuredContent']
            Draft202012Validator(tools[name]['outputSchema']).validate(v)
            return v
        blocks=re.findall(r'```json\n(.*?)\n\s*```',(ROOT/guide).read_text(),re.S)
        first=json.loads(blocks[0]);v=call('session_execute',first);sid=v['session_id']
        def completed(v):
            while v.get('status') in ('pending','running'):
                v=call('session_wait',dict(session_id=sid,wait_timeout_ms=1000))
            return v
        v=completed(v);assert v['values']==([42] if 'getting-started' in guide else [2]),v
        again=json.loads(blocks[1]);again['session_id']=sid
        assert completed(call('session_execute',again))['values']==v['values']
        assert call('session_wait',dict(session_id=sid,wait_timeout_ms=0))['error']['code']=='result_unavailable'
        v=completed(call('session_execute',dict(session_id=sid,code="saved = 9; error('stop')",wait_timeout_ms=1000)))
        assert v['session_usable'] and 'error' in v,v
        assert completed(call('session_execute',dict(session_id=sid,code='return saved',wait_timeout_ms=1000)))['values']==[9]
        v=completed(call('session_execute',dict(session_id=sid,code='return function() end',wait_timeout_ms=1000)));assert 'error' in v and v['session_usable']
        v=call('session_execute',dict(session_id=sid,code='return 7',wait_timeout_ms=0))
        assert completed(v)['values']==[7]
        kill=json.loads(blocks[2]);kill['session_id']=sid
        assert call('session_kill',kill)['process_exit_confirmed']
        print('PASS',guide,'discovery/schema, first result, state reuse, consumed result, runtime/conversion recovery, async poll, kill')
    finally:
        p.stdin.close()
        try:assert p.wait(timeout=8)==0,p.stderr.read()
        finally:
            if p.poll() is None:p.kill();p.wait()
