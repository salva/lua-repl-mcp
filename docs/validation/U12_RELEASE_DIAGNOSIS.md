# U12 release refresh diagnosis

Owner: [[card:card-d-c]]. Input HEAD `459f7fa93b3c956806bbaaa08f82d538eb7d2e98`
(clean worktree), including owning relay fix af80aa9 and EOF fix9f82e55.
This is diagnosis, not release acceptance.

## Current executed target

```sh
mkdir -p "$SAIVAGE_CARD_WORK_ROOT/u12-release-diagnosis"
SAIVAGE_CARD_WORK_ROOT="$SAIVAGE_CARD_WORK_ROOT/u12-release-diagnosis" sh tests/u9_installed.sh
```

Completed **exit0**. Fresh empty LuaRocks installation, installation-only Lua
paths, outside runtime cwd, installed-source byte comparison, native C embedding
host and all ten U8 conformance groups passed. Complete dynamically discovered
Lua and seven external drivers passed their specified outcomes. Despite the
legacy `installed_18_module_byte_identity` label, the comparison iterates over
all current source modules (including guardian/channel), not a fixed18 list.

Primary full output (39,343 bytes, read through final tail):
`work:///cards/card-d-c/processes/proc-1ff0dd7ccd58/stdout.log`.
Stderr was returned completely: installer notice, expected fail-closed reused/
stale allocation diagnostics, simulated unconfirmed-disposal warnings, the
explicit historical hardcoded64MiB assertion exit1, and contract checker PASS
14 schemas/7 tools/2 discovery results/23 examples/125 regressions. The historical
assertion is expected by the driver; it is not a current-production failure.

Current maximum test delivered67109058 bytes within134217728. Real installed
maximum result test delivered50331991 bytes within268435456 and unrelated session
remained useful. TERM-resistant native child reaped at20.011s with1962 responsive
turns. Preserved relay regression completed with guardian receipt880375.99803857
before deadline880377.78585395. Six real relay ordering cases and12 deterministic
cases passed. EOF empty/partial/complete same/next-turn variants passed. Installed
partial acquisition, stream/large reports,40 identity races and real fault tests
also passed. C host asserts state/thread identity, live handles, close-ack and
complete/partial handoff before parent reset/shutdown.

Versions observed/installed: Lua5.4.6, Node24.16.0, luaposix36.3-1,
bit32 5.3.5.1-1, jsonschema4.19.2. No lua5.5 executable on PATH; earlier
5.5 qualification is historical, not rerun here.

## Coverage classification: gap, not product rejection

Read AGENTS, launch, PLAN U9/U10/U12, U9 evidence, lifecycle report and independent
review, current integration report and harnesses. The accepted brief has two
remaining meaningful coverage gaps that passing ordinary installed tests cannot
waive:

1. `tests/u9_suite.py` does not invoke `u12_matrix.py` or the lifecycle Python
   driver. The matrix launches Lua with checkout cwd; lifecycle probe selects
   checkout CLI/cwd. They need an explicit installed/outside mode and fresh
   execution of the full watchdog/barrier matrix, including manager-only death,
   signal states, guardian loss and descriptor inheritance. Existing checkout
   independent audit is valid peer evidence only for its stated checkout.
2. Current real-agent JSON and interpretation are for package1007245423b48b5ff36f5b69638d75608c451247.
   Five runtime files changed since then (new guardian/channel, manager, server,
   supervisor). Therefore those trials cannot establish current U10 lifecycle/
   cancellation/deadline behavior. Real isolated trials, returned calls, semantic
   checking, exact client provenance and cleanup still need fresh execution.

Branch comparison: guardian-native receipt now owns execution deadlines rather
than stale manager mirror time; manager still owns accepted kill and consumption.
EOF classification separates remote endpoint loss from local channel failure,
with wait alone establishing confirmed exit. Current installed ordering/EOF tests
support these corrections. No manufactured failing test or runtime change needed.

Preserve all historical failures in the independent review. Issue8 remains
filed-not-fixed: timeout disconnect losing unrelated sessions is not a pass.
No isolated agent trial was launched during this diagnosis; no new client failure
or client version is inferred. Public docs/RELEASE and SPEC15 correction remain
outside this internal report. No shared runtime, host, generated state, credential,
service, restart, push or publication changes performed.
