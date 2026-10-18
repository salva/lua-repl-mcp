# F03 — Failed transport bypasses owned guardian reap

Reviewer C2-A03; medium importance, local backend ownership. **Accept narrowly**,
confirmed by skeptical source triage. Already-reaped failure branch is not a leak.
Source
[guardian.lua:299](../../../../lua_repl_mcp/guardian.lua#L299)–331,344–356.

Channel assertion can bypass wait then mark closed; shutdown refuses further
finalization. Long-lived host may retain guardian zombie. Not proof of leaked
worker after manager death; ordinary CLI exit limits exposure.

Focused option: separate closed descriptors from completed owned-child reaping,
allow idempotent bounded finalization after channel failure, retaining only owned
guardian PID/identity and original applicable disposal budget. Alternative caller-
owned guardian reap expands integration contract without need. No stale worker
PID fallback, second watchdog or unlimited shutdown wait. Contained guardian-exit/
EOF case in long-lived backend should prove ECHILD/reap and repeated shutdown;
failure must not erase unknown worker-exit facts or claim successful cleanup.
