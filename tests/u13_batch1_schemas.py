"""Validate actual affected runtime responses, not hand-written error examples."""
import json, pathlib, subprocess
import jsonschema
root = pathlib.Path(__file__).resolve().parents[1]
schema = json.loads((root / 'docs/schemas/api.json').read_text())
output = subprocess.run(['lua5.4', str(root / 'tests/u13_batch1_schemas.lua')], cwd=root, check=True, capture_output=True, text=True)
count = 0
for line in output.stdout.splitlines():
    row = json.loads(line)
    selected = dict(schema, **{'$ref': '#/$defs/' + row['tool'] + '_output'})
    jsonschema.Draft202012Validator(selected).validate(row['payload'])
    print('PASS', row['tool'], row['case'])
    count += 1
print('PASS actual output schemas', count)
