"""U5 red-stage implementation-presence check, NOT behavioral conformance.

The baseline has contracts and a private U4 supervisor but no public manager.
Ignore declarative contracts/schemas: they cannot allocate sessions or implement
wait/commit policy. A future passing result requires behavioral U5 tests too.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
files = sorted((root / 'lua_repl_mcp').rglob('*.lua'))
policy = [p for p in files if p.name not in ('contracts.lua', 'direct_schemas.lua')]
required = ('session_execute', 'session_wait', 'session_list', 'result_unavailable')
missing = []
print('U5 policy inventory (excluding contract/schema declarations):')
print(', '.join(str(p.relative_to(root)) for p in policy))
for token in required:
    owners = [str(p.relative_to(root)) for p in policy if token in p.read_text()]
    print(f'{token}: {owners or "ABSENT"}')
    if not owners:
        missing.append(token)
assert not missing, 'U5 manager policy implementation absent: ' + ', '.join(missing)
