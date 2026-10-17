"""Original U11 missing-deliverable regression; run from repository root."""
from pathlib import Path
import re
root = Path('.')
checks = []
def check(label, ok):
    checks.append(ok)
    print(('PASS' if ok else 'FAIL') + ': ' + label)
for path in ['site-docs', 'mkdocs.yml', 'docs/validation/WEBSITE.md']:
    check('required U11 deliverable exists: ' + path, (root/path).exists())
requirements = list(root.glob('*requirements*.txt')) + list(root.glob('docs/*requirements*.txt'))
check('dedicated pinned MkDocs requirements available', any(re.search(r'(?im)^mkdocs==[^\s]+', p.read_text()) for p in requirements))
check('generated /site/ ignored', '/site/' in (root/'.gitignore').read_text().splitlines())
readme = (root/'README.md').read_text()
guide = (root/'README-IF-YOR-ARE-AN-AI.md').read_text()
check('README links exact LLM consumer guide', '(README-IF-YOR-ARE-AN-AI.md)' in readme)
check('README has exactly one linked attribution', readme.count('Built with [Saivage](https://github.com/salva/saivage-v3)') == 1 and readme.count('Saivage') == 1)
check('LLM recipe uses progress-safe single-byte file read', 'protocol_input:read(1)' in guide)
release = (root/'docs/RELEASE.md').read_text()
for token in ['U9_EVIDENCE.md', '(SPEC.md)', 'U12 guardian ownership\nand U11 website work remain separate scope']:
    check('legacy RELEASE public boundary excludes ' + repr(token), token not in release)
print(f'RESULT: {checks.count(False)} gaps; {checks.count(True)} satisfied focused checks')
raise SystemExit(1 if not all(checks) else 0)
