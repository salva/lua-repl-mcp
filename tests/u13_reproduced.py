"""Bounded red-stage reproducer retained as affected-path regression.

Original a-red/check.py and four-failure output are preserved in card evidence.
Only selection adapts to the replacement explicit manifest; fake clocks advance
past the actual function deadlines (rather than a constant absolute epoch).
"""
import ast,pathlib,types,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
source=(ROOT/'tests/website_installed.py').read_text()
tree=ast.parse(source)
def load(name, env):
 node=next(n for n in ast.walk(tree) if isinstance(n,ast.FunctionDef) and n.name==name)
 exec(compile(ast.Module(body=[node],type_ignores=[]),str(ROOT/'tests/website_installed.py'),'exec'),env)
 return env[name]
class ReproducedGaps(unittest.TestCase):
 def test_pure_discovery_excludes_process_fixture(self):
  import json
  selected=[r['path'] for r in json.loads((ROOT/'tests/fixtures.json').read_text()) if r['run'] and r['kind']=='pure']
  self.assertNotIn('u12_audit_relay_red.lua',selected)
 def test_total_pending_deadline(self):
  calls=[]
  class Stop(Exception):pass
  def call(*args):
   calls.append(1)
   if len(calls)==20:raise Stop()
   return {'status':'running'}
  ticks=iter(range(0,100000,10))
  fn=load('completed',{'call':call,'sid':'fixture','time':types.SimpleNamespace(monotonic=lambda:next(ticks))})
  # Twenty one-second polls must not run without a total-scenario check.
  try: fn({'status':'pending'})
  except Stop: self.fail('20 pending polls reached without total-scenario deadline')
  except AssertionError: pass
 def test_complete_frame_deadline_even_when_readable(self):
  class Stop(Exception):pass
  reads=[];clock=[0]
  def now():clock[0]+=10;return clock[0]
  def read(*args):
   reads.append(1)
   if len(reads)==20:raise Stop()
   return b'x'
  stream=types.SimpleNamespace(write=lambda b:None,fileno=lambda:0)
  env=dict(seq=0,pending=b'',p=types.SimpleNamespace(stdin=stream,stdout=stream),json=__import__('json'),time=types.SimpleNamespace(monotonic=now),select=types.SimpleNamespace(select=lambda *args:([stream],[],[])),os=types.SimpleNamespace(read=read))
  try: load('rpc',env)('initialize',{})
  except Stop: self.fail('20 readable partial chunks accepted after absolute frame deadline')
  except AssertionError: pass
 def test_aggregate_not_product_owns_subreaper(self):
  s=(ROOT/'tests/u9_suite.py').read_text()
  self.assertTrue('subreaper' in s.lower() or 'containment' in s.lower(),'aggregate has no external containment entry/context')
unittest.main(verbosity=2)
