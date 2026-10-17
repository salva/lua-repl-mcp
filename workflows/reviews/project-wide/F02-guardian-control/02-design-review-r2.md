# F02 design review, round 2

The topology, bounded work quantum, original deadlines, acknowledgement ownership and removal of legacy snapshots resolve round 1's deferred architecture objection. Required changes concern contradictions in the selected design:

1. Reconcile 'only one payload transfer per direction is active; others queue ... handles' with 'transfers progress round-robin at packet boundaries'. Round-robin requires resumable state for multiple unfinished transfers. Choose serial completion or explicitly bounded multiplexed transfer states and receiver accounting; specify how metadata selects the corresponding incremental parser/validation state.
2. Classify all potentially input-sized metadata. cwd, stream paths, ready cwd, file_created paths and offending-value paths do not necessarily fit the 16KiB control record. State which bulk body carries them, which small intent references it, and that allocation cannot spawn until required creation options are validated and the original deadline is rechecked. A generic allocate intent must not truncate/reject otherwise legal path data or spawn with default options before its body arrives.
3. Integrate F03's legal-input/private-frame-fit resolution. Removing argument cloning's byte check alone cannot make an expanded internal execute record fit its existing worker budget.
4. Make constructor validation reconcile the fixed 1024-record cap with configurable admission and the promised disposal reserve for every admitted allocation. Reject incompatible internal configurations before resource acquisition or derive a sufficient bounded queue; do not fail only when disposal is needed.

Historical-baggage lens: the separate control path is justified, but packet multiplexing and resumable codec state are substantial review-induced additions. Define only the required state machine and remove the superseded one; no generic streaming framework or private-protocol compatibility mode is warranted.

VERDICT: CHANGES_REQUESTED
