# Astra testing and evidence review

Reviewer `openai/gpt-6-astra`, session `ses_eb45f3c17ffeXEETi1Yym3tHU4`.
Pinned source `701320b`; faithful condensed receipt, not automatic acceptance.
Inspected instructions, relevant SPEC/PLAN/current metaplan, inventory, containment,
deadlines, representative pure/process/host tests and validation records. No tests,
services, state, edits or process campaigns. External card receipts were not
independently read; supplied revision identity was not independently verified.

## Findings

### New T01 — worker reaping oracle, medium

SPEC§14.9 requires guardian spawn **and reap**. At
[tests/u12_lifecycle_red.py:84](../../../tests/u12_lifecycle_red.py#L84)–93,
a worker with unchanged identity in state Z passes. The same non-zombie alive
definition appears at [tests/u12_matrix.py:79](../../../tests/u12_matrix.py#L79)
and170–173. Defective guardian kills but fails to reap; external owner adopts the
zombie; oracle passes and subsequent harness cleanup hides missing product reap.
This is a coverage gap, **not proof present product leaks zombies**.

Minimal correction: one manager-only-crash case requires original worker identity
to disappear before external cleanup. Do not require guardian disappearance:
guardian itself may legitimately await external-parent reaping. Alternative is
one narrow observer reporting adopted unreaped workers. Demonstrate omitted-reap
mutation fails, then run corrected installed crash case under containment. Fold
into existing F02 qualification, no expanded matrix. Confidence high in oracle.

### Existing F11 — final frame byte after deadline, low

[tests/deadlines.py:11](../../../tests/deadlines.py#L11)–18 checks time before
select, not after final newline read. Readiness immediately before deadline with
read completion after deadline passes. This is a false-positive deadline oracle,
not an unbounded hang or defeated outer watchdog. Add final absolute-time check
with one fake-clock timely/late regression. Alternative: explicitly weaken helper
claim to readiness-budget check, but current stated contract is complete-frame.
Confidence high from control flow; no process campaign needed.

### Existing F02/F03 — maximum-record evidence

[tests/u7_maximum_process.lua:1](../../../tests/u7_maximum_process.lua#L1)–18
uses direct manager/client transport; unrelated-session check at44–46 occurs after
collection. Useful worker/transport test, not concurrent guardian bulk/control
proof. Current plan already requires the correct installed guardian path. Do not
count as new finding or demand maximal-count×size campaign from this alone.

## Strengths and historical baggage

Explicit selection/named expected-red assertions, independent external subreaper,
pidfd ownership/protected acquisition, real extracted-function deadline tests,
installed-path/byte identity checks, host/side-effect/ECHILD oracles and narrowed
historical claims have substantive value. Preserve them; approval/counts/old
filenames are not proof. Two narrow oracle changes and current owned qualification
are sufficient; no framework, universal migration or repetitive campaign.
