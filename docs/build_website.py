"""Read-only allowlist staging and strict, repeatable local MkDocs build."""
import argparse
import hashlib
import json
import os
import pathlib
import posixpath
import re
import shutil
import subprocess
import sys
from html.parser import HTMLParser
from urllib.parse import unquote, urlsplit
import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
PAGES = ('index getting-started manager custom-host embedding data-errors operations reference').split()
ALLOW = [*(f'site-docs/{p}.md' for p in PAGES), 'README-IF-YOR-ARE-AN-AI.md',
         'docs/MCP_EXAMPLES.md', 'docs/schemas/api.json']
ATTR = 'Built with [Saivage](https://github.com/salva/saivage-v3).'

def staged_name(name):
    return name.removeprefix('site-docs/')

def stage_links(name, text):
    """Resolve authored inline links before relocating allowlisted sources."""
    def rewrite(match):
        link = match[1]
        u = urlsplit(link)
        if u.scheme or u.netloc or not u.path:
            return match[0]
        target = posixpath.normpath(posixpath.join(posixpath.dirname(name), unquote(u.path)))
        assert target in ALLOW, (name, link, 'destination outside public allowlist')
        relative = posixpath.relpath(staged_name(target), posixpath.dirname(staged_name(name)) or '.')
        return '](' + u._replace(path=relative).geturl() + ')'
    return re.sub(r'\]\(([^)]+)\)', rewrite, text)

def boundary(text, home=False):
    if home:
        assert text.count(ATTR) == 1, 'missing/duplicate attribution'
        text = text.replace(ATTR, '')
    assert not re.search(r'saivage|workflows/|SPEC\.md|PLAN\.md|EVIDENCE|validation/|card-[a-z]|/work/|/tmp/|\.env\b|conversation|credential[s]?\s*[:=]', text, re.I), 'public boundary violation'

def manifest(path):
    return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(path.rglob('*')) if p.is_file()}

class Page(HTMLParser):
    def __init__(self, text):
        super().__init__(); self.ids=set(); self.links=[]; self.feed(text)
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if 'id' in a: self.ids.add(a['id'])
        for k in ('href', 'src'):
            if a.get(k): self.links.append(a[k])

def audit(output):
    pages={p: Page(p.read_text()) for p in output.rglob('*.html')}
    count=0
    for p, page in pages.items():
        for link in page.links:
            u=urlsplit(link)
            if u.scheme or u.netloc: continue
            if u.path.startswith('/'):
                assert u.path.startswith('/lua-repl-mcp/'), (p,link)
                target=(output / unquote(u.path.removeprefix('/lua-repl-mcp/'))).resolve()
            else:
                target=(p.parent / unquote(u.path)).resolve() if u.path else p
            if target.is_dir(): target=target/'index.html'
            assert target.is_relative_to(output) and target.is_file(), (p,link,target)
            if u.fragment and target in pages:
                assert unquote(u.fragment) in pages[target].ids, (p,link)
            count+=1
    for p in output.rglob('*'):
        if p.suffix in ('.html','.json','.xml','.md','.txt','.js','.css','.svg'):
            text=p.read_text()
            if p == output/'index.html':
                assert text.count('Saivage')==1
                assert text.count('https://github.com/salva/saivage-v3')==1
                text=text.replace('Saivage','').replace('https://github.com/salva/saivage-v3','')
            # Bootstrap's card-* component selectors are not work-card identifiers.
            forbidden = r'saivage|SPEC\.md|PLAN\.md|U9_EVIDENCE|workflows/|validation/|/work/|/tmp/|conversation'
            if p.suffix not in ('.css', '.js'):
                forbidden += r'|card-[a-z]'
            assert not re.search(forbidden,text,re.I),p
    assert (output/'docs/schemas/api.json').read_bytes()==(ROOT/'docs/schemas/api.json').read_bytes()
    assert not any(p.name in ('SPEC.md','AGENTS.md','RELEASE_PRE_U11.md') for p in output.rglob('*'))
    print(f'PASS: {len(pages)} HTML pages, {count} local links/assets/fragments; exact schema download; public boundary')

if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--work-dir', type=pathlib.Path, required=True)
    args=parser.parse_args(); work=args.work_dir.resolve();work.mkdir(parents=True,exist_ok=True)
    assert not work.is_relative_to(ROOT/'site-docs')
    boundary((ROOT/'README.md').read_text(),True)
    before={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ALLOW}
    stage=work/'stage'
    if stage.exists(): shutil.rmtree(stage)
    stage.mkdir()
    for name in ALLOW:
        text=(ROOT/name).read_text();boundary(text,name=='site-docs/index.md')
        dest=stage/staged_name(name)
        dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(stage_links(name, text))
    assert sorted(str(p.relative_to(stage)) for p in stage.rglob('*') if p.is_file())==sorted(n.removeprefix('site-docs/') for n in ALLOW)
    os.environ['SOURCE_DATE_EPOCH']='0'
    config=yaml.safe_load((ROOT/'mkdocs.yml').read_text());config['docs_dir']=str(stage)
    for n in (1,2):
        config['site_dir']=str(work/f'output-{n}')
        cfg=work/'mkdocs.yml';cfg.write_text(yaml.safe_dump(config,sort_keys=False))
        subprocess.run([sys.executable,'-m','mkdocs','build','--strict','--clean','-f',str(cfg)],check=True)
    a,b=manifest(work/'output-1'),manifest(work/'output-2');assert a==b, 'nondeterministic output'
    assert before=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ALLOW}
    output=ROOT/'site'
    if output.exists():shutil.rmtree(output)
    shutil.copytree(work/'output-1',output)
    audit(output.resolve())
    (work/'manifest.json').write_text(json.dumps(a,indent=2)+'\n')
    print(f'PASS: exact allowlist {len(ALLOW)} staged files; {len(a)} deterministic artifact files; source hashes unchanged')
