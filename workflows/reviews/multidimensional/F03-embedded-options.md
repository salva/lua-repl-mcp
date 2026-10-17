# F03 — Embedded evaluator option names are missing

Reviewer-local DOC01. **Accept documentation-only; low severity, local impact.**
Source: [embedding.md:58–65](../../../site-docs/embedding.md#L58),
[limits.lua:4–14](../../../lua_repl_mcp/limits.lua#L4).
Guide advertises nested evaluator bounds without accepted keys. Users must inspect
source to configure max_bytes, max_depth and diagnostic_bytes; invalid names fail.

Add a compact options table or example with units, defaults and diagnostic minimum
derived from current loss-notice bytes. Do not duplicate a new normative contract,
freeze obsolete defaults, add configuration features or reinterpret F03 depth work.
Check documented options plus one invalid configuration using pure handler tests.
Coordinate with existing U13 source-link/docs edits. No fix performed.
