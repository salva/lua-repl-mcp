# Progressive termination repair (scoped follow-up)

For [[card:card-c-b-f]], explicit repair direction following accepted status v10.
The failing `u6_review_progressive_termination.lua` was a correct contract test,
not a faulty fixture. Changed only owning supervisor support plus focused tests;
this is not the full U12 guardian/crash-lifecycle implementation.

`worker_supervisor.abort` now freezes the original cause and monotonic origin,
closes channels and sends TERM. All disposal paths already share abort. Step
clamps poll delay to the next retry/phase/total deadline; reaps before retries;
sends at most one eligible signal per turn; switches to KILL at20s even if the
last TERM retry was less than1s earlier; stops at30s without a catch-up burst.
Repeated abort cannot reset origin/cause. Confirmed exit suppresses retries.
The existing fallback removes the worker, marks exit unconfirmed and retains
minimal eventual-reap PID bookkeeping. Completed results and manager consumption
logic are unchanged. Signals do not establish reaping or descendant containment.

Focused tests:
- Unchanged `u6_review_progressive_termination.lua`: initial15, required15, pass.
- New `u6_progressive_policy.lua`: deterministic .999/1/7.5/19.9/20/20.9/21/30
  turns, exact phase transition, no catch-up, preserved cause/deadline, poll clamp,
  reap-before-retry,30s fallback, and single very late turn without late KILL.
- New `u6_progressive_process.lua` with Python28s process-group watchdog: real
  child sets TERM ignore before readiness barrier, stays live through TERM phase,
  KILL transition after20s, confirmed reap, ~1980 responsive event-loop turns.
  Failure cleanup kills/reaps; watchdog contains the isolated group.

Native paths as in prior capacity review. Commands: Lua review/policy/ordering;
Python u6_process/u4_process/u5_process/u7_process; supplementary U4 error tests,
U5/U6 policy, approved capacities/preallocation/configuration/metadata-flood/U2,
contract checker, diff check. Completed batch exit0, output
`work:///cards/card-c-b-f/processes/proc-79098d26bbea/stdout.log`, full artifact
read. U4 fifteen groups, U5/U6 28/21 validated responses, all five U7 process
groups pass. U7 fairness467 ticks; default private16777347/67108864,
output50331991/268435456. Supplementary batch exits0:
`work:///cards/card-c-b-f/processes/proc-1efd2793bb66/stdout.log`; checker system
jsonschema4.10.3 remains supplementary, not pinned4.19.2/U8 acceptance.
Real watchdog invocation initially used inline Python, exit0 after20.0105s;
a durable equivalent driver was then added for reproducibility.

Earlier capacity evidence remains applicable: no relevant codec/config/default
changes. Historical64MiB red stays historical. No scope expansion to guardian
spawn/reap ownership, manager crash/signal boundary, installation or U8 external
acceptance. U12 owner must still implement and test its independent guardian and
race-safe ownership/handoff requirements; installed U8/U9 and affected process
checks need refreshing after that ownership change. Focused tests passing is not
full project or sibling acceptance. No push or shared runtime modification.
