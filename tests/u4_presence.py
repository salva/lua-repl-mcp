"""Preserved red-stage implementation-presence reproducer, not conformance."""
from pathlib import Path
files = sorted(Path('lua_repl_mcp').rglob('*.lua'))
print('Production Lua inventory:', ', '.join(str(p) for p in files))
required = ('protocol_version', 'file_created', 'startup_error', 'startup_timeout_ms')
missing = []
for token in required:
    owners = [str(p) for p in files if token in p.read_text()]
    print(f'U4 required protocol/startup marker {token}: {owners or "ABSENT"}')
    if not owners:
        missing.append(token)
assert not missing, 'U4 worker transport/startup implementation absent: ' + ', '.join(missing)
