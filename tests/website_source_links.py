"""Preserved F10 reproducer plus deterministic relocation/fragment regressions."""
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit, unquote

# Original red-stage source-destination oracle (including its controls).
files=[Path('README.md'),Path('README-IF-YOR-ARE-AN-AI.md'),*sorted(Path('site-docs').glob('*.md')),Path('docs/MCP_EXAMPLES.md')]
failures=[]; good=0
for p in files:
 for dest in re.findall(r'\]\(([^)]+)\)',p.read_text()):
  u=urlsplit(dest)
  if u.scheme or u.netloc or not u.path: continue
  target=p.parent/unquote(u.path)
  if not target.exists():
   failures.append((str(p),dest,str(target)))
  else: good+=1
for p,d,t in failures: print(f'FAIL source link: {p}: {d} -> missing {t}')
print(f'RESULT: {len(failures)} missing local source destinations; {good} existing local destinations (fragments not checked)')
assert not failures

sys.path.insert(0, str(Path('docs').resolve()))
from build_website import ALLOW, stage_links
from markdown import Markdown
md=Markdown(extensions=['toc'])
ids={}
for name in [*ALLOW, 'README.md']:
 if name.endswith('.md'):
  md.reset(); html=md.convert(Path(name).read_text())
  ids[name]=set(re.findall(r' id="([^"]+)"',html))
for p in files:
 for dest in re.findall(r'\]\(([^)]+)\)',p.read_text()):
  u=urlsplit(dest)
  if u.scheme or u.netloc or not u.fragment: continue
  target=(p.parent/unquote(u.path)).resolve() if u.path else p.resolve()
  name=str(target.relative_to(Path.cwd()))
  assert unquote(u.fragment) in ids[name], (p,dest)
for name in ALLOW:
 text=Path(name).read_text()
 staged=stage_links(name,text)
 assert staged==stage_links(name,text)
 if name.startswith('site-docs/'):
  assert '](../docs/' not in staged and '](../README-' not in staged
assert stage_links('site-docs/embedding.md', '[guide](../README-IF-YOR-ARE-AN-AI.md#embedded-host-use)')=='[guide](README-IF-YOR-ARE-AN-AI.md#embedded-host-use)'
controls='[remote](https://example.org/x) [local](#section)'
assert stage_links('site-docs/index.md',controls)==controls
assert stage_links('docs/MCP_EXAMPLES.md','[schema](schemas/api.json)')=='[schema](schemas/api.json)'
for invalid in ['../docs/SPEC.md','../../outside.md']:
 try: stage_links('site-docs/index.md',f'[invalid]({invalid})')
 except AssertionError: pass
 else: raise AssertionError('non-public destination admitted')
print('PASS: source fragments, deterministic staged links, unchanged remote/fragment/nested links; allowlist rejection')
