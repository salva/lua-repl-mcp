# Distinguish execution time from logical commitment

Guardian completion time protects an execution that actually finished before a
hard deadline from delayed relay. Kill/cancellation currently linearize at manager
acceptance, before buffered results may be logically committed. The contract must
explicitly distinguish those boundaries or choose one authority consistently.
Neither existing tests nor prior approval settle the choice. Preserve destructive
cancellation, immutable recorded outcomes and single-consumer commitment; do not
undo the demonstrated delayed-relay timeout repair.
