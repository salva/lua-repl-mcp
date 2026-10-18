# Cycle 2 — testing and evidence

Reviewer: fresh `openai/gpt-6-astra`, session `ses_eb21db3deffeAWeHYac4PrE2wK`.
Pin `a600754a4cfb06983c278f633bd262721588f860`. Condensed review receipt;
findings await consolidated skeptical triage, not automatic implementation.

## Verdict and limits

Substantive improvement over701320b. One narrow residual test-oracle weakness,
not a demonstrated product defect. Prior crash-reaping and final-frame gaps fixed.
Source/doc/history inspection only, no tests/native execution/services/state or
edits. Current card execution receipts unavailable in this snapshot; executable
assertions are distinguished from reported successful runs. No broad campaign.

## C2-T01 — blocked-bulk kill lacks observed overlap

**Residual F02 evidence weakness; low-to-medium, test-local; high confidence.**
Sources: [u13_blocked_control.lua:20](../../../../tests/u13_blocked_control.lua#L20)–33,
[u13_independent_metadata.lua:20](../../../../tests/u13_independent_metadata.lua#L20)–34,
[BATCH3-INTEGRATED-MATRIX.md:22](../../project-wide/BATCH3-INTEGRATED-MATRIX.md#L22)–24.

First fixture waits for execute-command flush, disables bulk reads, immediately
kills. It does not observe result production/partial receipt/backpressure first.
Second fixture dispatches small operation immediately after first command flush.
Potential false pass: controls complete before large result exists, despite an
implementation that stalls control once bulk fills. Large return expression
does not prove temporal overlap. blocked_control.lua22 comment still describes
superseded lockstep design.

Counterevidence: [u13_partial_crash.py:23](../../../../tests/u13_partial_crash.py#L23)–27,
58–64 establishes partial-relay barrier before manager death;
[u13_result_encoding_control.lua:39](../../../../tests/u13_result_encoding_control.lua#L39)–45
establishes real encoding checkpoint before kill. Valuable distinct coverage;
neither proves blocked-bulk fixture's missing overlap. Uninspected historical
receipts may supply additional coverage; no actual product starvation alleged.

Smallest correction: strengthen existing blocked-bulk kill with observed partial
transfer, withhold reads and require kill completion before restoring reads,
reusing existing partial-crash technique. No additional matrix. Alternative narrow
claim to control with disabled bulk reads and cite actual established-pressure
receipt; stronger durable barrier regression preferred. Exact needed overlap
assertion must be critically checked against current tests before fixing.

## Fixed findings and preserved assertions

- Worker reaping: [reap_oracle.py:14](../../../../tests/reap_oracle.py#L14)–22 rejects
  same-identity zombie; u13_reap_oracle.py11–30 negative control leaves zombie and
  requires rejection. u12_lifecycle_red.py84–86/u13_partial_crash.py62–64 require
  disappearance before fixture completion. External cleanup starts after exit/
  interruption/deadline (containment.py75–83), not credited as product reap proof.
- Final read: deadlines.py18 checks strict completion time; u13_final_read.py10–22
  accepts before, rejects equality/after. No process campaign required.
- Async validation: u4_error_drain.lua/u6_ordering.lua retain failure/outcome
  assertions while awaiting validation. u13_native_validation.lua17–37 also tests
  raw-frame noncompletion, multiple turns, cancel, deadline equality/after and reap
  before validation completion. Not merely weakening to eventual success.
- Obsolete snapshot assumptions removed appropriately: u12_aggregate_process.lua
  checks nine retained results and unchanged transfer counts; u7_snapshot.lua keeps
  overflow/nonconsumption/fidelity checks using supported retained values.

## Evidence strengths and limitations

Installed isolation checks outside cwd, installation-only paths, module byte
identity and actual resolution (u9_installed.sh12–28, u9_suite.py16–18,
u12_environment.py14–32). Exact-V u13_maximum_guardian.lua20–25 and exact-I
u13_cli_original.py18–28 exercise real paths but do not alone prove concurrency.
u13_copy_diagnostics.lua35–81 independently compares cleaned output and allocation
growth at fixed output budget without quota/OOM claims. Integrated matrix58–69
records installed receipt/measurements; SDK claim33 references separate status,
not checked-in returned transcript, so reviewer cannot independently certify it.
Historical transcripts/evidence parsers are not fresh proof. Git diffs establish
assertion evolution, not authentication of actual red/green executions.

## Historical baggage/evolutionary bias

Removing synchronous/lockstep/snapshot test assumptions is correct when observable
contracts remain. Async concurrency assertions need overlap barriers. Counts,
phases/old approval do not create obligations. Preserve intentionally trusted Lua,
avoid expanded machinery and unrelated repeat qualification. Strengthen or
accurately qualify this one oracle, then consolidate existing receipts.
