# Independent skeptical triage — cycle 2

Fresh Astra `ses_eb218e6cbffenkwpQUkHYMPzHu`. Verified all four reports against
immutable `a600754` only. No probes/native execution/state/edits/delegation.
Condensed receipt of actual returned triage; this is not native acceptance.

## Dispositions

| Claim | Decision and critical qualification | Local issue |
| --- | --- | --- |
| A01 resolved-request cancellation | Accept local predicate; busy rejection/completed creation and resolved no_execution wait lack terminal execution guard. Response availability alone is not completion: active zero-wait execution must remain cancellable. | F01 |
| A02 independent death versus allocation retirement | Accept, highest priority. Dead control frees public credit before bulk release; replacement can hit guardian assertion and shut unrelated workers down. Source mechanism clear, actual native schedule not independently reproduced. | F02 |
| A03 transport closure versus child ownership | Accept narrowly. EOF before wait then closed bypasses future reap. If wait already reaped guardian before raising, that branch has no zombie. Frequency/accumulation unmeasured. | F03 |
| A04 handler input | Reject as separate issue: duplicate D01/Q03 handler branch. | F05 |
| D01 embedded byte/context propagation | Accept two actual branches: configured decoder bound and canonical re-admission through protocol/evaluator. One-line variable fix insufficient. | F05 |
| D02 depth1 discovery | Accept fixed schema allowance independent of user policy. Expanded output schema goes deeper than the cited six-container lower bound. Dynamic schema-depth framework not needed. | F06 |
| Q01 oversized generated path | Accept high priority. Encoded metadata overflow makes recoverable serialization failure fail private encoding. Native worker exit is source-derived, not rerun. Distinct from fixed bounded diagnostic-message retention. | F04 |
| Q02 creation canonical re-admission | Accept explicit AND implicit creation: execute original-wire admission can succeed while allocation options are still rechecked. Tabbed cwd need not exist to establish wrong validation stage; no successful filesystem claim. | F05 |
| Q03 undeclared names | Merge handler duplicate; separately remove accidental from_json host-global dependency unless explicit option truly needed. Not sandbox issue. | F05 |
| Q04 repeated depth walk | Defer. Accepted-shape equivalence supports redundancy but changing traversal alters checkpoint cadence/first error; no required correctness fix depends on it. | F08 |
| T01 overlap oracle | Accept narrowly. Command flush/disabled reads do not prove produced result overlap. Partial-crash/encoding tests refute claims of no concurrency coverage but not this gap. | F07 |

Confidence high in source mechanisms, with explicit native/performance uncertainty.

## Necessary repair qualifications

- F01: distinguish resolved rejection/creation/no_execution wait from active
  zero-wait, active wait, starting allocation and accepted kill still cleaning up.
  Use existing fields; no generalized state machine.
- F02: moving release to control alone is insufficient. Late bulk currently
  asserts known allocation (guardian.lua303); late ack/dispose and repeated
  turnover need bounded identity-safe handling. Choose smallest control retirement/
  ack or proven ordering, preserve original startup origin if replacement waits.
  Never restore dependency on bulk drainage, drop assertion or retain unbounded
  dead entries/tombstones. Small-capacity barrier-controlled test suffices.
- F03: retain owned guardian PID until reaped; transport-closed is not finalized.
  One WNOHANG attempt is insufficient while guardian still disposing. Finalization
  must be idempotent/bounded, cover already-reaped branch, and never signal stale
  worker PIDs or impose caller ownership transfer/new supervisor.
- F04: optional path may be omitted or truthful ancestor selected. Budget encoded
  bytes, including escaping. Preserve completed result_serialization_error,
  discarded values/effect truth and recovery; no misleading pointer truncation.
- F05: admit original network bytes once; keep raw structural/depth validation and
  fresh copying downstream. Ordinary in-memory calls retain canonical checks.
  Provenance must originate at actual ingress, not a caller-supplied trust flag.
  Reuse existing mechanism, not general provenance framework.
- F06: small explicit fixed schema bound with current-response regression suffices;
  enforce user D independently and do not raise minimum D.
- F07: observed partial transfer proves overlap, not necessarily kernel
  backpressure. Match claim to actual barrier; establish pending/blocked output
  if claiming that condition. Reuse same technique for F02 turnover regression.

## Suggested grouping and validation

Prioritize guardian retirement/finalization with attached overlap proof. Local
cancellation and error metadata can follow as independent focused commits; finish
embedded/explicit/implicit admitted-input flow and discovery. Keep F08 out of
delivery dependencies. Serialize shared manager/guardian edits regardless of order.

Pure/inert cases cover cancellation branches, metadata private encoding at legal
floors/escaped keys, explicit dataflow and depth1 discovery/D+1 rejection. Native
contained cases prove small-capacity repeated turnover under observed partial
relay, unrelated-session continuity, stale reports, guardian reap before harness
cleanup, and real same-session serialization recovery. In-memory negative controls,
fresh copies and exact boundaries remain. Schema checks are not native proof.
No additional matrix or unrelated campaign is justified.

## Historical baggage and evolutionary bias

Independent ownership/control/liveness, original deadlines, raw copies, generations
and commitment delivered real guarantees. Residual integration assumptions—not
architecture itself—need fixes. Prior approval/passes do not disprove source traces;
minimality is not excuse to waive real loss. Conversely no demonstrated general
starvation/OOM/latency/sandbox issue justifies new frameworks or stale-PID fallback.
Previously fixed work stays closed; optional cleanup remains optional.
