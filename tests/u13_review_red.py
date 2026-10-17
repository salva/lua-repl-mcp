"""Bounded regressions for independent review R1/R2; no product guardian."""
import ast, os, pathlib, sys, types, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from containment import run
W=pathlib.Path(os.environ['SAIVAGE_CARD_WORK_ROOT'])/'a-review-red'
W.mkdir(exist_ok=True)
class ReviewBoundaries(unittest.TestCase):
 def test_acquisition_sigterm(self):
  pidfile=W/'pid'; result=W/'survived'
  pidfile.unlink(missing_ok=True);result.unlink(missing_ok=True)
  fixture="import os,time; open(%r,'w').write(str(os.getpid())); time.sleep(30)" % str(pidfile)
  inner="""import sys,os,signal,time
sys.path.insert(0,%r)
import containment
real=containment.subprocess.Popen
def injected(*a,**kw):
 p=real(*a,**kw)
 end=time.monotonic()+2
 while not os.path.exists(%r) and time.monotonic()<end:time.sleep(.001)
 os.kill(os.getpid(),signal.SIGTERM)
 return p
containment.subprocess.Popen=injected
containment.run([sys.executable,'-c',%r],3)
""" % (str(ROOT/'tests'),str(pidfile),fixture)
  observer="""import subprocess,sys,pathlib,time
p=subprocess.Popen([sys.executable,'-c',%r]);p.wait(timeout=4)
pid=int(pathlib.Path(%r).read_text());time.sleep(.1)
pathlib.Path(%r).write_text(str(pathlib.Path('/proc/'+str(pid)).exists()))
""" % (inner,str(pidfile),str(result))
  self.assertEqual(run([sys.executable,'-c',observer],6),0)
  self.assertFalse(pathlib.Path('/proc/'+pidfile.read_text()).exists(),'safety reap')
  self.assertEqual(result.read_text(),'False','acquired fixture survives owner TERM')
 def test_late_completion(self):
  tree=ast.parse((ROOT/'tests/website_installed.py').read_text())
  node=next(n for n in ast.walk(tree) if isinstance(n,ast.FunctionDef) and n.name=='completed')
  clock=[0.0];calls=[]
  def call(*args):
   calls.append(args);clock[0]=22.0
   return {'status':'completed','values':[7]}
  def now():
   t=clock[0]
   if t==0:clock[0]=14.0
   return t
  env={'call':call,'sid':'fixture','time':types.SimpleNamespace(monotonic=now)}
  exec(compile(ast.Module(body=[node],type_ignores=[]),'website_installed.py','exec'),env)
  with self.assertRaisesRegex(AssertionError,'total scenario deadline'):
   env['completed']({'status':'running'})
  self.assertEqual(len(calls),1)
unittest.main(verbosity=2)
