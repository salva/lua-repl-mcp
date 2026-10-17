# F03 plan review, round 2

Required changes:

1. Test escaped original network input through an actual worker with a legal custom configuration near the existing coupled floors and small result allowance. Current tests must establish dispatch and one-time execution, not only successful ingress/copier validation. Include numeric-token expansion as well as string escaping, following the chosen representation/fit design.
2. Correct step 3's instruction to reject 'hostile metamethod tables'. Valid raw tables with such metatables must remain accepted without invoking their metamethods. Reject unsupported raw shape/data, not the mere presence of metatables. Snapshot tests/u1.lua:114-119 and 151-156 explicitly establish this behavior, and SPEC requires raw inspection. Assert both valid raw data acceptance and invalid raw data rejection with zero metamethod invocations.

The precise D/D+1/D+8 checks, max512 paths and separation of library from network byte provenance are otherwise implementable. Do not accidentally turn the safer copier into a new metatable restriction.

VERDICT: CHANGES_REQUESTED
