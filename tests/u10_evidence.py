#!/usr/bin/env python3
"""Assert semantics of retained Saivage-native tool evidence, not model claims."""
import json,sys
calls=[c for path in sys.argv[1:] for c in json.load(open(path))['toolInvocations']]; results=[]
for c in calls:
 if c['tool']!='mcp_tool_call':continue
 result=c['result']; native=result.get('data',{}).get('result',{}); s=native.get('structuredContent')
 if s is None:continue
 texts=[b['text'] for b in result.get('content',result.get('data',{}).get('content',[])) if b['type']=='text']
 assert len(texts)==1 and json.loads(texts[0])==s, 'text/structured mismatch'
 assert native['isError']==('error' in s), 'tool error not preserved'
 results.append((c['params']['toolName'],c['params'].get('args',{}),s))
assert results,'missing real native results'
def seen(test):return any(test(n,a,s) for n,a,s in results)
checks={
 'explicit_create': lambda n,a,s:n=='session_create' and 'session_id' in s,
 'implicit_execute':lambda n,a,s:n=='session_execute' and not a.get('session_id') and 'session_id' in s,
 'pending':lambda n,a,s:s.get('status')=='running',
 'terminal':lambda n,a,s:s.get('status')=='completed' and 'values' in s,
 'single_consumption':lambda n,a,s:s.get('error',{}).get('code')=='result_unavailable',
 'syntax_recovery_error':lambda n,a,s:s.get('error',{}).get('code')=='lua_syntax_error' and s.get('session_usable'),
 'runtime_recovery_error':lambda n,a,s:s.get('error',{}).get('code')=='lua_runtime_error' and s.get('session_usable'),
 'serialization_recovery_error':lambda n,a,s:s.get('error',{}).get('code')=='result_serialization_error' and s.get('session_usable'),
 'list':lambda n,a,s:n=='session_list' and 'sessions' in s,
 'kill':lambda n,a,s:n=='session_kill' and 'error' not in s,
 'hard_timeout':lambda n,a,s:s.get('error',{}).get('code')=='execution_timeout',
}
missing=[]
for name,test in checks.items():
 ok=seen(test);print(('PASS' if ok else 'MISSING'),name)
 if not ok:missing.append(name)
assert not missing,missing
# Correlate retained results by session and order, not merely independent sightings.
assert any(n=='session_execute' and a.get('wait_timeout_ms')==1 and s.get('status')=='running' for n,a,s in results)
for i,(n,a,s) in enumerate(results):
 if n=='session_execute' and s.get('status')=='running' and a.get('wait_timeout_ms')==1:
  sid=s['session_id']; later=[t for tool,args,t in results[i+1:] if tool=='session_wait' and args.get('session_id')==sid]
  assert later[0].get('values')==[81] and later[1].get('error',{}).get('code')=='result_unavailable'
assert any(s.get('values')==[42,None,{'tag':'json','value':7}] for n,a,s in results)
assert any(s.get('values')==[None,1,1] for n,a,s in results), 'side effects exactly once'
assert any(s.get('values')==[True,True] for n,a,s in results), 'independent globals/functions'
assert any(s.get('error',{}).get('code')=='execution_timeout' and s.get('process_exit_confirmed') and s.get('session_usable') is False for n,a,s in results)
assert any('timed out after 30000ms' in c['result'].get('error','') for c in calls), 'client deadline not observed'
assert any("is not running" in c['result'].get('error','') for c in calls), 'client containment not observed'
print('PASS ordered finite pending/terminal/consumed; JSON/persistence/isolation; hard vs client deadlines')
print('PASS native text equality/error preservation for',len(results),'actual agent calls')
