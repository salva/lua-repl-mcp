# F07 — Disabled reads do not prove established blocked-result overlap

Reviewer C2-T01; low-to-medium, test-local residual F02 evidence.
**simplify/strengthen**, confirmed by skeptical test-source triage. Source
[u13_blocked_control.lua:20](../../../../tests/u13_blocked_control.lua#L20)–33;
[u13_independent_metadata.lua:20](../../../../tests/u13_independent_metadata.lua#L20)–34.

Immediate control after command flush can finish before result exists. Test claims
blocked bulk but observes no transfer/backpressure barrier. Actual partial-crash
and encoding-checkpoint tests are counterevidence at different boundaries, not
proof of this fixture's overlap. No product starvation claim.

Focused option: reuse observed partial-transfer/progress technique, ensure result
is in-flight and reads remain withheld across kill/metadata completion; if claiming
actual backpressure establish insufficient transport capacity/output pending, not
merely submitted code or a timer. Alternative narrow fixture/matrix wording and
cite an existing genuinely overlapping proof. Prefer durable targeted assertion,
not another matrix. Remove obsolete lockstep comment; keep exact claim boundaries.
