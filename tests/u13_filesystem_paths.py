"""Actual Linux PATH_MAX-1 cwd and relative redirection, using dirfd construction."""
from containment import enter
enter(120)
import json, os, shutil, subprocess
from pathlib import Path
from u12_environment import CWD, PRELUDE

root=Path(os.environ['SAIVAGE_CARD_WORK_ROOT'])/'maximal-filesystem-path'
root.mkdir(exist_ok=True)
# All disposable directories remain beneath this explicitly owned child.
base=root/'tree'
base.mkdir()
fd=os.open(base,os.O_RDONLY|os.O_DIRECTORY)
try:
    pathmax=os.fpathconf(fd,'PC_PATH_MAX'); namemax=os.fpathconf(fd,'PC_NAME_MAX')
    assert pathmax==4096 and namemax==255,(pathmax,namemax)
    def descend(count):
        global fd
        names=[]
        while count:
            # Reserve at least two chars for slash+component when more follows.
            n=min(namemax,count)
            if count-n==1: n-=1
            name='d'*n
            os.mkdir(name,dir_fd=fd)
            child=os.open(name,os.O_RDONLY|os.O_DIRECTORY,dir_fd=fd)
            os.close(fd); fd=child; names.append(name)
            count-=n
            if count: count-=1
        return '/'.join(names)
    suffix=descend(pathmax-1-len(str(base))-1)
    cwd=str(base)+'/'+suffix
    assert len(cwd)==pathmax-1
    # One maximal relative pathname, resolved under maximal cwd. The emitted
    # absolute path is longer than PATH_MAX but remains truthful metadata.
    directories=descend(pathmax-1-2)
    relative=directories+'/f'
    assert len(relative)==pathmax-1
    options=json.dumps(dict(cwd=cwd,stdout_path=relative,stderr_path=relative))
    bootstrap=PRELUDE+'''
local c=require('lua_repl_mcp.codec')
local x=require('lua_repl_mcp.worker_posix')
local b=require('lua_repl_mcp.guardian').new{}
local m=require('lua_repl_mcp.manager').new{supervisor=b}
local function take(r)
 local stop=x.now()+30
 repeat local v=m:commit(r,function() return true end); if v then return v end; m:step(0); assert(x.now()<stop) until false
end
local ok,err=pcall(function()
 local options=assert(c.decode('''+json.dumps(options)+'''))
 local result=take(m:accept('session_create',options))
 assert(result.session_id,assert(c.encode(result)))
 assert(m.sessions[result.session_id].cwd==options.cwd)
 local worker=m.sessions[result.session_id].worker
 assert(worker.files_complete and #worker.created_paths==1)
 assert(worker.created_paths[1]==options.cwd..'/'..options.stdout_path)
 local r=take(m:accept('session_execute',{session_id=result.session_id,code='io.write("proof"); io.flush(); return 73'}))
 assert(r.values[1]==73)
 local killed=take(m:accept('session_kill',{session_id=result.session_id}))
 assert(killed.process_exit_confirmed)
 print('PASS actual_maximal_cwd_relative_redirection cwd='..#options.cwd..' relative='..#options.stdout_path..' absolute='..#(options.cwd..'/'..options.stdout_path))
end)
b:shutdown(); assert(ok,err)
'''
    p=subprocess.run(['lua5.4','-e',bootstrap],cwd=CWD,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=90)
    assert p.returncode==0,(p.returncode,p.stderr.decode(errors='replace'))
    assert os.stat('f',dir_fd=fd).st_size==5
    print(p.stdout.decode(),end='',flush=True)
finally:
    os.close(fd)
    shutil.rmtree(base)
