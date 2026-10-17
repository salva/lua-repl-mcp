# Explicit lifecycle ordering authority

Focused option: manager remains logical outcome authority; guardian timestamps
are evidence for hard-deadline eligibility only. Completion is logically recorded
when manager validates/applies it. Kill/cancellation accepted before that point
can discard buffered values; once manager records completion, cleanup cannot
rewrite it. Clarify this distinction in contract and user lifecycle guidance.

One-level-up option: guardian serializes completion and destructive commands in
one generation-bound event order, with manager waiting for authoritative decision
acknowledgement. This can align all races but changes kill acceptance semantics
and must be integrated with independent control progress.

Prefer the focused explicit two-boundary model if contract analysis confirms it
preserves the owner's recorded-outcome rule; otherwise select the ordered guardian
option before implementation. Do not implement contradictory halves or introduce
an unspecified operator decision midway through the runtime batch.
