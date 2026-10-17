# F01 — Diagnostic cleaning allocates the full expanded text

Reviewer-local CQ-N01. **Accept local correction; medium severity, local impact.**
Source: [errors.lua:5–14](../../../lua_repl_mcp/errors.lua#L5),29–46 at `701320b`.
Every source character becomes a retained table entry before concatenation and
post-hoc clipping. Large thrown strings thus cause avoidable memory amplification
despite a small diagnostic output budget. No measured OOM or universal execution
memory guarantee is alleged; trusted Lua can allocate arbitrary memory itself.

Use a budget-aware local cleaner. Preserve UTF-8 boundaries, exact notice and
combined message/traceback flags, including invalid bytes after the retained prefix.
Scanning for flags may remain linear in source size; do not promise bounded runtime
or add execution quotas. Compare memory growth without brittle exact allocator
thresholds. A shared local helper is proportionate; general streaming codec is not.

Preserve message-first combined prefix and current lossless behaviour: do not
reserve notice bytes unconditionally when no loss/invalid byte occurs. Late invalid
bytes must still affect flags, and reserving the notice can itself cause truncation.

Validate long ASCII/multibyte/invalid diagnostics, combined fields and follow-up
execution. Reconcile live errors.lua before implementation. No fix performed.
