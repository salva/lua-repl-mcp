#!/usr/bin/env python3
"""Send bounded U10 instructions to an isolated Saivage Analyst; retain real results.
Never point this fixture at the active development instance.
"""
import argparse, json, pathlib, urllib.request
PROMPT = '''This is an isolated U10 Lua MCP integration trial, not a project implementation request. Do not start_project, modify source, inspect secrets or use shell. Use only mcp_server_control, mcp_tools and mcp_tool_call on server lua. Start lua, discover exact schemas and bindingId. The five actual tool names are session_create, session_execute, session_wait, session_list, session_kill. Discover each by exact name with mcp_tools; if optional toolName cannot be omitted use these exact names, never wildcard or /all. The execution tool uses wait_timeout_ms (confirm schema) not invented names. Then execute the scenarios below, interpreting every returned pending/terminal/tool-error result explicitly in your final response. Use bounded Lua workloads (os.execute("sleep 1") where needed). Tool arguments must follow discovered schemas. Keep session IDs from returned results, not invented IDs.
1. Explicit create_session; execute persistent global n=40 and function add(x) return n+x end; next execution returns add(2), nil, JSON argument via ...; assert values and null/count. Create another independent session and prove isolation.
2. Implicit execute with omitted/null session_id returning JSON object; preserve its returned ID. Synchronous results, no implicit expression return.
3. Async execute sleep 1 then return 73, wait_timeout=0; interpret pending. list_sessions must not consume. wait finite short then wait unbounded to terminal; another wait must be result_unavailable. Execute on same session again to prove usable.
4. Syntax error, runtime error after side effect, and serialization error returning function; interpret recoverable errors and verify side effects persist exactly once in later valid execution.
5. Execute async sleep 2, finite wait expires preserving work; unrelated session returns 42. Kill active session, consume its fatal result, repeated kill follows contract.
6. Hard timeout independently: implicit execute sleep 2 with timeout_ms=100, wait unbounded. Interpret timeout and prove unrelated session works.
7. Client deadline independently: implicit execute sleep 65, timeout_ms=null, wait_timeout=null. This intentionally exceeds Saivage's client invocation timeout; do not retry it. After the error, list sessions, and prove unrelated session usable. Explain observed cancellation/session effect, without assuming tool error equals hard Lua timeout.
Finally kill all remaining sessions, list, and stop lua. Summarize each scenario with observed values/errors and uncertainty. Do not claim any unexecuted action passed. Limit total tool calls to 45. Do not use other tools.'''
def main():
    p=argparse.ArgumentParser();p.add_argument('--instructions');p.add_argument('--url',default='http://127.0.0.1:18081');p.add_argument('--output',required=True);a=p.parse_args()
    assert a.url == 'http://127.0.0.1:18081', 'fixture restricted to isolated port'
    req=urllib.request.Request(a.url+'/api/chat',data=json.dumps({'content':pathlib.Path(a.instructions).read_text() if a.instructions else PROMPT}).encode(),headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(req,timeout=600) as r: result=json.load(r)
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2)+'\n')
    calls=result.get('toolInvocations',[])
    assert calls, 'no actual agent tool evidence returned'
    assert any(c['tool']=='mcp_tool_call' for c in calls), 'no actual MCP invocation'
    print('retained actual agent response:',len(calls),'tool invocations')
if __name__=='__main__':main()
