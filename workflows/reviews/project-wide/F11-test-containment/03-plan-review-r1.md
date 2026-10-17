# F11 plan review

Required changes: add a nested-wrapper timeout/crash injection proving the selected containment owner removes all owned groups and reaps the immediate child. Cover aggregate-driver timeout during a fixture, not only fixture-local timeout. Preserve the historical expected-red test as an explicitly asserted disposition, not a broad nonzero-exit exception.

Existing partial-frame and perpetual-pending cases remain required. These changes make the new runner prove its own failure boundary rather than merely reorganizing filenames.

VERDICT: CHANGES_REQUESTED
