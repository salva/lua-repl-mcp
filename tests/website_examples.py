"""Validate every authored website tool block and independently assert defaults."""
import json, pathlib, re, subprocess
from jsonschema import Draft202012Validator
root=pathlib.Path(__file__).resolve().parents[1]
schema=json.loads((root/'docs/schemas/api.json').read_text())
names={'getting-started':['session_execute','session_execute','session_kill'],
       'manager':['session_execute','session_execute','session_wait'],
       'custom-host':['session_create','session_execute'],
       'data-errors':['session_execute']}
count=0
for page,tools in names.items():
    blocks=re.findall(r'```json\n(.*?)\n```',(root/f'site-docs/{page}.md').read_text(),re.S)
    for tool,block in zip(tools,blocks,strict=True):
        Draft202012Validator({'$ref':'#/$defs/'+tool,'$defs':schema['$defs']}).validate(json.loads(block));count+=1
subprocess.run(['lua5.4','-e', '''local l=require('lua_repl_mcp.limits')
local c=l.connection(); assert(c.input_bytes==16777216 and c.values_bytes==16777216)
assert(c.diagnostic_bytes==65536 and c.max_depth==128 and c.worker_bytes==67108864)
assert(c.response_bytes==134217728 and c.output_bytes==268435456)
local a=l.admission();assert(a.sessions==64 and a.ordinary==256 and a.control==32 and a.kill_reserve==8)
'''],cwd=root,check=True)
print(f'PASS {count} website JSON arguments; current runtime resource defaults')
