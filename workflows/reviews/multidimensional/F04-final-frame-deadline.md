# F04 — Shared helper accepts a late final newline

Existing U13 F11, **accept small residual correction; low severity, test-local**.
Source: [deadlines.py:11–18](../../../tests/deadlines.py#L11).
Time is checked before select but not after the final read. Readiness before
expiry followed by completion after expiry passes, contradicting helper's
complete-frame claim. Outer watchdog still bounds the process; no unbounded hang
is established. Before/equal/after final-read fake-clock regression suffices.

Orchestrator independently reproduced this at pinned source: start0, select0.9,
final newline1.1 with deadline1.0 returns success. Pure in-process fake clock/read,
no product or spawning fixtures. This is a demonstrated oracle defect, not a
product timing measurement. Check final absolute deadline before success; weaker
readiness-only wording would be smaller code but would not meet current claim.
Reconcile any live F11 correction. No extra campaign/framework. No fix performed.
