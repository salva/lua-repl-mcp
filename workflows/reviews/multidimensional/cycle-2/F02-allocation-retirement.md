# F02 — Independent disposal and allocation credit disagree

Reviewer C2-A02; high importance, cross-cutting guardian/manager. **Accept**,
confirmed by skeptical source triage, native schedule not rerun. Source
[guardian.lua:79](../../../../lua_repl_mcp/guardian.lua#L79)–84,102,173–177,293–296,324–325;
[manager.lua:225](../../../../lua_repl_mcp/manager.lua#L225)–237.

Manager frees public capacity on independent death control, guardian counts dead
allocation until release over blocked bulk. Replacement may hit guardian capacity
assertion and destroy unrelated sessions. Scheduling-derived, not native proof.
Small configured capacity is sufficient; no maximum-population ritual.

Focused option: retire/discard matching immutable allocation through independent
control and acknowledge ownership/credit, retaining bounded stale-record handling.
Alternative hold replacement until independent retirement acknowledgement with
original startup deadline. Select simpler proven variant. Do not remove capacity
assertion, ignore retained-dead growth, wait on bulk or revive stale payloads.
One barrier-controlled full-capacity kill/replacement case with unrelated live
session and late bulk, plus accounting invariants, provides targeted evidence.
