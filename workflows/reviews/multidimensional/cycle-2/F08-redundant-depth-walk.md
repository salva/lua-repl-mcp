# F08 — Optional redundant depth walk

Reviewer C2-Q04; low importance, local simplification. **Defer**, confirmed by
independent skeptical triage; no required correctness work depends on this cleanup.
Source
[contracts.lua:48](../../../../lua_repl_mcp/contracts.lua#L48),56–65.
Reviewer argues clone D+2 already checks exactly what later per-argument walk checks.
No measured latency violation; raw traversal safety/checkpoints and error paths
must be preserved if removed. Prior review introduced it, but age alone is not
reason to delete. Optional focused removal only after equivalence at D/D+1,
empty/scalar/null/tuple/error-path and cooperative checkpoint boundaries is shown.
Alternative leave it while fixing real defects. No framework or delivery blocker.
