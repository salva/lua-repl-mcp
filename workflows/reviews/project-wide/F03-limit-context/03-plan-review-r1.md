# F03 plan review

Required changes:

1. Add exact depth-boundary assertions using the finalized per-boundary accounting, including the highest accepted configured depth through direct and guardian-backed managed paths.
2. Retain negative structural-copy tests for cycles, malformed keys, nonfinite/unsafe numbers, invalid UTF-8, and hostile metamethods, plus fresh argument identity and empty-shape/null behavior.
3. Distinguish wire ingress tests from direct Lua-library input tests, and test actual configured ingress rather than bypassing protocol.handle through transport.submit.

These close concrete gaps introduced by replacing the existing validation-bearing clone; they are not a new generalized validation framework.

VERDICT: CHANGES_REQUESTED
