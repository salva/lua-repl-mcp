# F03 design review, round 3

No required changes. Immutable validated spans for selected code/args/options resolve the original-wire versus internal re-encoding fit gap while preserving the coupled floors. Disjoint selected spans, fixed private metadata, identity binding and worker-side validation give a concrete representation and trust boundary; public envelopes and arbitrary trusted-raw APIs are excluded. Canonical library-input accounting remains separately defined.

Depth accounting, fresh structural copies, raw metatable-bearing table acceptance and strict data validation are consistent with the earlier approved contracts and F02 body transfer.

Historical-baggage lens: preserving minimal wire representation is justified by the demonstrated expansion defect and avoids another capacity increase solely to preserve serialization-as-copy. No parallel legacy validation path or new metatable restriction is retained.

VERDICT: APPROVED
