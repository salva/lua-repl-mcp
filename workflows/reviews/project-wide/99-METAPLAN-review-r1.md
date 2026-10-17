# Metaplan review

Required changes:

1. Finalize F02 topology/control-service bounds and F13 event authority in the reviewed designs. Batch D cannot begin with a design gate that delegates these central choices to executors. Define their joint ownership of partial bulk transfer, small lifecycle events, disposal and result acknowledgements.
2. Resolve the dependency inversion: batch C's F06 and F09 declare dependencies on F07, currently in D. Complete a concrete F05/F07 failure-mapping interface before C, then implement guardian propagation with D, or move the dependent work. 'Can be specified' is not a satisfied dependency. Express F01 -> F03 and joint F03/F05 integration explicitly within B.
3. Incorporate F03's per-boundary limits/copy-validation contract, F06's exact preparation-error classification, F08's exact duplicate-ID policy/release boundary, and F11's nested containment ownership before their implementation batches.
4. Require guardian-backed installed CLI coverage for F02's aggregate-result/control/deadline case. Older U7 native-supervisor fairness and maximum-payload fixtures remain useful but cannot certify the changed guardian topology. Keep the original-deadline and noncompleting-report cases explicit.
5. Update 00-INDEX.md's stale 'inventory pending' status and checklist to reflect actual audit/planning progress, without claiming implementation or approval. Clarify that publication is excluded from this repair/acceptance scope but separately authorized for the orchestrator; Saivage remains no-publish. The existing metaplan separation is otherwise appropriate.

Assessment: work-package scope, focused alternatives, no publication acceptance gate, preservation of owner mandates, and removal of accidental machinery are sound. Do not convert the requested clarifications into more generic frameworks, compatibility layers or independent review stages. Historical accepted tests must be reclassified where the selected normative rule changes them; evidence must identify current executable paths and exact revisions.

No runtime edits or commits were performed by this reviewer. Reviews concern all 39 r1 analysis/design/plan documents plus the metaplan, subsystem map and index.

VERDICT: CHANGES_REQUESTED
