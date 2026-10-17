# Independent refresh at b8464fb

For [[card:card-c-b-f]], current diagnose node. Read current SPEC14.4, PLAN U7/U12, workflows/LIMITS_CHANGE.md, U7 evidence and affected source/tests. The authorized capacity correction removes the previous owner-decision block. It does not implement the separately newly normative progressive termination policy.

## Capacity and original scope: passing

Independently reran actual production defaults (not test overrides): I=V=16777216, D=65536, H=1048576, W=67108864, R=134217728, O=268435456. B=34996224 and response floor122814464. `limits.connection` uses checked add/multiply, bounds all scalar inputs and applies identical floors to defaults/overrides with no exemption or unresolved-fit flag. Manager validates before backend construction. New `tests/u7_review_preallocation.lua` instruments backend construction and confirms incompatible worker/response/output and overflow inputs are rejected before backend construction/allocation; exits0.

`u7_default_maximum.lua` passes: legal input/values16777216 each, full response67109058 <134217728, original success (not fallback), exact ID and duplicated text equality. `u7_coupled_defaults_red.lua` remains unchanged and separately exits1 with194 excess over its historical hardcoded64MiB. That is historical evidence, NOT current-default failure. No reason to alter it or repeat the old blocked classification.

Aggregate metadata fallback, snapshot non-consumption, max-ID diagnostics/notices/artifacts, two-created-file bound, admissions/reserved kills/cancellation, frame/value/depth boundaries and configuration propagation all pass. Default worker predecode retention at -1/at/+1 measured67108863/67108864/67108864. Source caps third file_created before retention, so earlier proof's two-path assumption is now enforced.

Independent live reruns: U3 seven POSIX groups, U4 fifteen worker groups, U5/U6 28/21 schema-validated responses and all five U7 process watchdog groups pass. Default private peak16777347/67108864, output50331991/268435456; configured20MiB private20971651/25165824, output62914903/134217728. Three stopped-reader cases retain200001, short progress65536; fairness saturated256 waits/control reservation/cancel/kill passes,469 ping ticks before deadline response. Unrelated session usable. Prior malformed-worker repair and its three tests remain green; R1 argument matrix/false-close and supplied-channel U2 host/short writes/handoff pass.

Coverage supports original U3–U7 capacity/state/transport obligations with generated-bound reasoning, deterministic race cases and sampled real schedules, not a claim all possible interleavings ran. Public text expansion <=3 times encoded payload and ID<=I; conservative B includes I+V+6D+H. Unbounded aggregate metadata uses permitted bounded fallback, not a universal original-list-success promise. No changes to production source were needed for this capacity refresh.

## New current-spec failure: progressive termination not implemented

b8464fb updates SPEC14.4 to immediate TERM, one-second TERM retries through20s, then KILL retries for10s, total30s monotonic cleanup. PLAN U12 owns this lifecycle correction. Current `worker_supervisor.abort` still sends SIGKILL immediately and only has the old30s fallback. New minimal `tests/u6_review_progressive_termination.lua` intercepts signal delivery without targeting a real PID and exits1: **initial_signal=9, required_TERM=15**. Owning scope is supervisor/guardian lifecycle U12, not capacity arithmetic or a flaky fixture. It also lacks staged retries; existing green deadline/cleanup suites assert the previous policy and cannot establish the new one. SPEC14.9 guardian/signal/crash cleanup is likewise a separately planned U12 obligation, not established by U3–U7 reruns. No runtime/source repair or U12 implementation begun in this diagnosis node.

Thus capacity block resolved and original bounds target is green, but blanket current-SPEC U3–U7 acceptance cannot be issued. Classification **failing_test** for newly required termination behavior, not blocked on a nonexistent limits decision. Later verification owns acceptance.

## Commands and evidence

Native paths: LUA_PATH='./?.lua;./?/init.lua;./.luarocks/share/lua/5.4/?.lua;./.luarocks/share/lua/5.4/?/init.lua;;', LUA_CPATH='./.luarocks/lib/lua/5.4/?.so;;'. Lua5.4.6/local luaposix36.3-1 environment unchanged.

Fail-fast batch exit0 `work:///cards/card-c-b-f/processes/proc-57af303f448d/stdout.log`: three U4 malformed-error tests; U5/U6 deterministic/order/deadlines; u7_approved_limits_red/configuration/configuration_red/metadata_budget_red/snapshot/metadata_flood/default_maximum/max_id; bounds_red/admission/pending_flood_red/pending_ownership/transport/boundaries/frame_budgets/encoding_red/adversarial; Python U3/U4/U5/U6/U7 drivers; U2 core/R1 tests/live host; docs/check_contracts.py; diff check. Complete artifact read including final process sections. Checker passes14 schemas/7 tools/2 discovery/23 examples/125 cases using system jsonschema4.10.3, supplementary rather than pinned4.19.2 acceptance.

Separate current termination red: `proc-4c8260ffeb66`, exit1, complete inline output. Historical capacity red `proc-4f8e4a7a9c96`, exit1, complete inline output. Preallocation test `proc-f1cdddbfd4c1` exits0. One initial LIMITS_CHANGE read used wrong docs/ path; corrected to workflows/; no missing input remains.

## Downstream refresh

U8 owner: rerun u8_stdio_red.py/u8_live.py/u8_direct_host.lua with corrected production defaults; cancellation, one-consumer commit, framing and initialization remain required external checks. U9 owner: fresh scoped clean install (`tests/u9_installed.sh`), then installed U8 suite, worker exec/module resolution/no checkout leakage and actual host integration. After U12 ownership/escalation changes, repeat affected U4–U9 cleanup/cancel/deadline/fairness tests and guardian-specific races. Do not carry current capacity green forward as U12 or installed/client acceptance. No sibling acceptance, shared runtime change, push or publication performed.
