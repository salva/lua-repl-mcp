# Saivage stdio deadline contains unrelated sessions

Status: observed client limitation; no shared-runtime change authorized or made.
Revision: deployed dedicated release `39ffe231` per OPERATIONS.md, version 0.1.0;
source constant `MCP_INVOKE_TIMEOUT_MS=30000`. Package `5da1952`, installed 0.1.0-1.

## Reproduce

Use isolated local project, configure installed stdio server as `lua` per
[trial matrix](../../validation/SAIVAGE_INTEGRATION.md). Run
`python3 tests/u10_agent.py --output /disposable/response.json` against the
fixture-restricted 127.0.0.1:18081. Discover exact tool names (omit toolName or
provide actual names, not wildcard). Have an existing idle session. Invoke once:

```json
{"code":"os.execute('sleep 65'); return 65","execution_timeout_ms":null,"wait_timeout_ms":null}
```

Expected product-level isolation: client deadline is distinct from a Lua hard
deadline; cancellation of one execution should not imply unrelated sessions are
usable if the client tears down their shared transport. U10 requires measuring
and honestly documenting this behavior, not masking it as a server defect.

Observed once in one deadline attempt: agent received
`Tool 'session_execute' on server 'lua' timed out after 30000ms`; next session_list
received `MCP server 'lua' is not running`. Explicit start plus fresh discovery
produced a different binding; session_list returned empty, then fresh execution
returned [42]. Old worker PIDs 14647 and 14659 were absent afterward. Thus all
sessions on that stdio connection were lost, not merely the deadline-bound one.

Exact actual agent call/result evidence is
[attempt2.json](../../validation/saivage/attempt2.json), final agent interpretation
[interpretation.md](../../validation/saivage/interpretation.md). Native tool errors
remain distinguishable from client timeout (the latter lacks structuredContent).

Independent comparison: clean installed U8 suite exit 0 (diagnosis log linked in
trial document); `finite_wait_busy_preservation_wait_cancellation_active_kill`
checks cancellation preserving unrelated sessions on a live transport. This is
not a standalone reproduction of Saivage's 30s timer. Server disconnect disposal
is expected; client containment is the source of the larger blast radius.
Read-only inspection of Saivage server-runtime.ts confirms timeout path calls
closeAdmission/directContainment when no response completes. No evidence of a
Lua server violation here. Impact: any long synchronous tool call can terminate
other persistent workers; use bounded/async polling below the client deadline.
Do not silently replay lost-state operations.

Upstream issue filed with operator authorization:
https://github.com/salva/saivage-v3/issues/8 — request a 15-minute invocation
default, configurable overrides, and explicit documentation of stdio containment.
Filing does not mean the upstream timeout has changed or the limitation is fixed.

## Refreshed package trial (current)

Rerun against clean-installed package
`1007245423b48b5ff36f5b69638d75608c451247`, same Saivage release39ffe231,
2026-10-17. Fresh real-agent result again: sleep65 with null server deadlines
returned client timeout30000ms; next list server-not-running; new binding restart
lists empty and fresh [42] works. Frequency refreshed1/1, cumulative2/2 targeted
attempts. Exact returned evidence and agent interpretation:
[refresh agent](../../validation/saivage/refresh-1007245/agent.json),
[interpretation](../../validation/saivage/refresh-1007245/interpretation.md),
[current matrix](../../validation/SAIVAGE_INTEGRATION.md).
Current independent installed complete suite passes cancellation/isolation and
disconnect cleanup, log
`work:///cards/card-c-e-a/processes/proc-aa0916a2e131/stdout.log`.
The increased package limits/progressive worker termination do not repair Saivage
shared-stdio containment. Issue8 is filed, **NOT FIXED**; unrelated-session
preservation across this timeout remains a limitation, never a pass.
