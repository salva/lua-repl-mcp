"""Real U12 watchdog/barrier matrix; only isolated test process groups contained.
Run with the recorded project-local Lua module environment.
"""
import concurrent.futures
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import tempfile
import time
from u12_lifecycle_red import ROOT, identity


def run(mode, state):
    work = Path(os.environ['SAIVAGE_CARD_WORK_ROOT']) / 'u12-matrix'
    work.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=work) as tmp:
        tmp = Path(tmp)
        marker = tmp / 'abrupt'
        # Trigger abrupt exit at a safe test barrier without production hooks.
        script = '''local u=require('posix.unistd'); local s=require('lua_repl_mcp.server')
local serve=s.serve
s.serve=function(io,options)
 local pause=io.pause
 io.pause=function()
  local f=_G.io.open(%s,'r')
  if f then f:close(); u._exit(77) end
  pause()
 end
 return serve(io,options)
end
s.main()''' % json.dumps(str(marker))
        if mode == 'fatal':
            script=script.replace('u._exit(77)', 'error("injected manager event-loop failure")')
        if state == 'spawn':
            # Test-only wrapper inherited by guardian/worker; blocks immediately
            # before worker exec, proving ownership in the spawn/readiness gap.
            hook = """local x=require('lua_repl_mcp.worker_posix')
x.u.execp=function()
 local f=assert(io.open(%s,'w')); f:write(x.u.getpid()); f:close()
 while true do x.t.nanosleep{tv_sec=1,tv_nsec=0} end
end
""" % json.dumps(str(tmp/'spawned'))
            script = hook + script
        p = subprocess.Popen(['lua5.4', '-e', script], cwd=ROOT,
                             stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, bufsize=0, start_new_session=True)
        buf = b''
        serial = 0
        tracked = []
        def send(method, params):
            nonlocal serial
            serial += 1
            p.stdin.write((json.dumps(dict(jsonrpc='2.0', id=serial, method=method, params=params))+'\n').encode())
            return serial
        def get(id):
            nonlocal buf
            deadline = time.monotonic()+10
            while True:
                while b'\n' not in buf:
                    left = deadline-time.monotonic()
                    assert left > 0 and select.select([p.stdout], [], [], left)[0], 'RPC watchdog'
                    data = os.read(p.stdout.fileno(), 65536)
                    assert data, 'unexpected EOF'
                    buf += data
                line, buf = buf.split(b'\n', 1)
                value = json.loads(line)
                if value.get('id') == id:
                    return value['result']
        def rpc(method, params):
            return get(send(method, params))
        def children(pid):
            return [int(v) for v in Path(f'/proc/{pid}/task/{pid}/children').read_text().split()]
        def alive(pid, original):
            now = identity(pid)
            return now and now[0] == original[0] and now[1] != 'Z'
        try:
            rpc('initialize', dict(protocolVersion='2025-11-25', capabilities={},clientInfo=dict(name='matrix',version='1')))
            p.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
            guardian = children(p.pid)[0]
            tracked.append((guardian, identity(guardian)))
            fifo = tmp/'fifo'
            os.mkfifo(fifo)
            if state in ('startup','spawn'):
                send('tools/call',dict(name='session_create', arguments=dict(stdin_path=str(fifo))))
                deadline = time.monotonic()+8
                while not children(guardian):
                    assert time.monotonic()<deadline, 'spawn barrier'
                    time.sleep(.005)
                worker = children(guardian)[0]
                if state == 'spawn':
                    while not (tmp/'spawned').exists():
                        assert time.monotonic()<deadline, 'pre-exec barrier'
                        time.sleep(.005)
                    assert int((tmp/'spawned').read_text())==worker
                # /proc syscall is an observation barrier: worker is blocked in
                # FIFO open, not merely scheduled sometime after fork.
                while state == 'startup':
                    syscall = Path(f'/proc/{worker}/syscall').read_text().strip()
                    if syscall.startswith(('257 ', '2 ')):
                        break
                    assert time.monotonic()<deadline, 'FIFO native startup barrier'
                    time.sleep(.005)
            else:
                v=rpc('tools/call',dict(name='session_create',arguments={}))['structuredContent']
                worker=children(guardian)[0]
                if state in ('native','infinite','subprocess','ignoring'):
                    barrier=tmp/'executing'
                    code='local f=assert(io.open('+json.dumps(str(barrier))+',"w")); f:write("ready"); f:close(); '
                    if state=='ignoring':
                        code='local s=require("posix.signal"); s.signal(s.SIGTERM,s.SIG_IGN); '+code+'while true do end'
                    elif state=='native':
                        code+='local u=require("posix.unistd"); local f=require("posix.fcntl"); local fd=assert(f.open('+json.dumps(str(fifo))+',f.O_RDONLY)); u.read(fd,1)'
                    elif state=='subprocess':
                        # Descendant stays alive during guardian liveness EOF;
                        # containment is test-only, not a process-tree promise.
                        import shlex
                        shell='echo $$ > '+shlex.quote(str(tmp/'descendant'))+'; exec sleep 30'
                        code+='os.execute('+json.dumps('sh -c '+shlex.quote(shell)+' &')+'); while true do end'
                    else:
                        code+='while true do end'
                    r=rpc('tools/call',dict(name='session_execute',arguments=dict(session_id=v['session_id'],code=code,wait_timeout_ms=0)))
                    assert r['structuredContent']['status']=='running'
                    deadline=time.monotonic()+8
                    while not barrier.exists():
                        assert time.monotonic()<deadline, 'execution barrier'
                        time.sleep(.005)
                    if state=='native':
                        while not Path(f'/proc/{worker}/syscall').read_text().startswith(('257 ', '2 ')):
                            assert time.monotonic()<deadline, 'native open barrier'
                            time.sleep(.005)
            descendant=None
            if state=='subprocess':
                deadline=time.monotonic()+8
                while not (tmp/'descendant').exists():
                    assert time.monotonic()<deadline, 'descendant-ready barrier'
                    time.sleep(.005)
                descendant=int((tmp/'descendant').read_text()); desc_identity=identity(descendant)
                assert desc_identity and desc_identity[1]!='Z'
            tracked.append((worker,identity(worker)))
            assert tracked[-1][1][2]==guardian
            start=time.monotonic()
            if mode in ('abrupt','fatal'):
                marker.touch(); expected=77 if mode=='abrupt' else 1
            elif mode=='guardian_loss':
                os.kill(guardian,signal.SIGKILL); expected=1
            elif mode=='eof':
                p.stdin.close(); expected=0
            elif mode=='repeat':
                os.kill(p.pid,signal.SIGTERM)
                # Repeated requests must not preempt guardian disposal.
                for _ in range(5):
                    if p.poll() is not None: break
                    os.kill(p.pid,signal.SIGTERM)
                expected=143
            else:
                os.kill(p.pid,mode)
                expected=-9 if mode==signal.SIGKILL else 128+mode
            assert p.wait(timeout=34)==expected, (mode,state,p.returncode,expected)
            if mode=='guardian_loss':
                assert b'guardian lost' in p.stderr.read(), 'missing fail-closed diagnostic'
                # Guardian death has no safe PID ownership fallback. Worker is
                # explicitly contained below, not falsely claimed disposed.
            else:
                deadline=start+32
                while any(alive(pid,ident) for pid,ident in tracked):
                    assert time.monotonic()<deadline, ('disposal watchdog',tracked)
                    time.sleep(.01)
            if descendant is not None:
                assert alive(descendant,desc_identity), 'inheritance proof requires live descendant through disposal'
            print('PASS matrix',mode,state,'elapsed',round(time.monotonic()-start,3),flush=True)
            return True
        except Exception as e:
            print('FAIL matrix',mode,state,str(e),flush=True)
            return False
        finally:
            try: os.killpg(p.pid,signal.SIGKILL)
            except ProcessLookupError: pass
            p.wait(timeout=5)
            for stream in (p.stdin,p.stdout,p.stderr):
                stream.close()

if __name__=='__main__':
    cases=[(mode,state) for mode in (signal.SIGINT,signal.SIGTERM,signal.SIGKILL,'abrupt')
           for state in ('idle','startup','spawn','infinite','native')]
    cases += [('abrupt','subprocess'),('guardian_loss','infinite'),('repeat','native'),('eof','infinite'),('repeat','ignoring'),(signal.SIGKILL,'ignoring'),('fatal','native'),('fatal','startup')]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results=list(pool.map(lambda args:run(*args),cases))
    raise SystemExit(0 if all(results) else 1)
