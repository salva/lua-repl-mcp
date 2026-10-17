# F02 plan review, round 2

Required changes:

1. Reflect the finalized serial-versus-multiplexed transfer model from the design. If multiplexed, test interleaved partial tokens, per-transfer offsets/state, discard and bounded aggregate state; if serial, remove round-robin claims.
2. Add creation metadata exceeding the control-record size, with options arriving partially and expiring before completion. Assert no default/late spawn and an accurately classified creation result. Include large ready/file-path metadata without permitting control starvation.
3. Include the F03 original-input versus private execute-frame fit regression and configuration/disposal-reserve compatibility checks before allocation.

The installed guardian aggregate test, original-deadline tests, independent external containment, and explicit scheduling allowance are now appropriately specified. No further topology-selection gate is requested.

VERDICT: CHANGES_REQUESTED
