# Contain every acceptance fixture

1. Inventory all scripts and their actual process-spawning behaviour. Replace
   ambiguous glob discovery with explicit pure/process/historical classification.
2. Run process fixtures through isolated, externally bounded group-contained
   wrappers; validate timeout/failure cleanup, not only successful runs.
3. Replace readiness-then-readline with complete-frame absolute deadlines and
   bound repeated pending-result scenarios by an overall monotonic deadline.
4. Inject partial frames, ignored TERM, fixture crashes and perpetual pending;
   assert bounded failure and no surviving owned processes.
5. Run the installed combined suite through the corrected driver, distinguishing
   source tests, installed resolution and historical expected failures.

Dependency: none; execute first so later evidence is trustworthy. Importance 4/5,
transversality 4/5. Retain existing useful assertions and real POSIX coverage.
