# One external containment owner for each acceptance tree

Focused alternative patches ambiguous globs and each existing wrapper. Select a
small explicit fixture manifest and one external supervisor for an entire
acceptance invocation, separate from the aggregate driver and product guardian
under test. The manifest identifies pure/process/historical fixtures, wrapper,
deadline and exact expected historical disposition. No generic test framework.

On the qualified Linux test target the supervisor is a child subreaper, owns a
dedicated fixture process group, and survives driver/local-wrapper timeouts. All
wrappers under its inherited supervision context stop creating independent
sessions/groups and defer tree cleanup to this owner. Their local failure paths
remain useful but are not the last line of containment. Standalone wrapper use
enters the same supervisor rather than adding nested owners.

The supervisor enforces absolute overall deadline and fixture deadlines, signals
only its owned group/children, and reaps before returning. On aggregate crash/
timeout it kills the fixture group, then drains/reaps adopted descendants. For
tests deliberately creating a new session/group, subreaper adoption plus observed
live child ownership prevents stale-PID signalling; do not enumerate and kill
arbitrary matching host processes. Explicitly qualify this Linux-only test helper
separately from product POSIX requirements. If subreaper support is unavailable,
report this containment qualification blocked, not silently downgrade protection.

Use complete-frame absolute read deadlines and total polling-scenario deadlines
inside that ownership boundary. This replaces incomplete/nested watchdog habits
rather than layering another unprotected wrapper on top.
