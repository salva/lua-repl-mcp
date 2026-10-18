# Cycle 2 — architecture and lifecycle

Fresh Astra `ses_eb21e1fe3ffe3Ka5kKDb0DJc4W`, pin `a600754`.
Condensed receipt of source-derived allegations, pending skeptical consolidated
triage. Reviewer read required contracts/current plans, runtime and integrated
matrix. No tests, children, edits, live state, credentials or services.

## C2-A01 — cancellation of a resolved rejection destroys unrelated execution

**High; high source confidence; residual F08 completion boundary.**
[manager.lua:54](../../../../lua_repl_mcp/manager.lua#L54)–58 busy rejection sets
r.response without r.execution;142–146 retains r.session;189–203 completed guard
only recognizes terminal execution. [client_transport.lua:143](../../../../lua_repl_mcp/client_transport.lua#L143)–161
can handle multiple frames before response commitment.

Proposed scenario: A running, B rejected busy against same session, cancel B before
its response commit. Cancel kills A although B never ran. Successful creation
before commitment similarly lacks execution guard. Existing completed-cancel test
u13_batch1_reproduced.lua43–49 covers terminal execution, not these branches.

Smallest repair: local predicate recognizing resolved operation responses while
preserving active zero-wait cancellation and accepted-kill cleanup. Alternative
explicit operation-completion state touches more transitions; not first choice.
No general lifecycle framework. Focus busy-rejection/completed-create cases.

## C2-A02 — public capacity freed before guardian allocation credit retired

**High; high source confidence, scheduling-dependent; new F02 repair boundary.**
[guardian.lua:79](../../../../lua_repl_mcp/guardian.lua#L79)–84 counts all allocation
entries, including dead awaiting release;102 release only on bulk.293–296 death
control marks terminating mirror dead; [manager.lua:225](../../../../lua_repl_mcp/manager.lua#L225)–237
frees public session capacity, but guardian324–325 releases only after dead bulk
report. Guardian173–177 exception path shuts remaining workers down.

Proposed scenario: configured capacity full; large result blocks guardian bulk;
kill another session confirmed through control; replacement admitted before old
dead bulk report/release. Guardian rejects capacity and shuts down unrelated
workers. Small configured capacity suffices; no maximal-count×size campaign.

Smallest repair: independent retirement/ack matching control disposal; immutable
allocation identity rejects stale bulk, bookkeeping remains bounded. Alternative
defer replacement until control retirement acknowledgement while preserving
original startup origin. Waiting on bulk restores old dependency. Do not merely
drop capacity assertion or ignore dead-entry growth. Target one turnover/barrier
scenario, not backend redesign.

## C2-A03 — channel failure closes backend before reaping guardian

**Medium; high source confidence; new ownership-finalization gap.**
[guardian.lua:299](../../../../lua_repl_mcp/guardian.lua#L299)–331 assertions precede
guardian wait(WNOHANG);344–352 failure sets closed/closes descriptors/raises;
355–356 shutdown returns when closed. Long-lived host manager backend observes
EOF before wait, then cannot finalize owned guardian. Repetition can accumulate
guardian zombies until host exits. CLI exit limits practical impact. This is not
a manager-death worker leak claim.

Smallest repair: distinguish transport closed from owned-child finalization,
retain guardian PID and allow bounded reaping after failure. No former-worker-PID
fallback. Caller ownership transfer would unnecessarily expand public integration.
No new watchdog/supervisor. Need contained guardian-exit/channel-failure cleanup
qualification for long-lived backend and idempotent shutdown.

## C2-A04 — embedded input configuration lost downstream

**Medium; high source confidence; residual F03; overlaps C2-D01.**
[handler.lua:23](../../../../lua_repl_mcp/handler.lua#L23),57,63;
[protocol.lua:89](../../../../lua_repl_mcp/protocol.lua#L89);
[evaluator.lua:11](../../../../lua_repl_mcp/evaluator.lua#L11)–14;
[codec.lua:263](../../../../lua_repl_mcp/codec.lua#L263),281.
options.input_bytes applies to frame, undeclared input_bytes global configures
decoder, then validation/copy defaults16MiB. Larger legal input is rejected and
unrelated host global can affect decoding. Carry local effective limit plus
admitted-wire context through both passes. Variable fix alone insufficient;
fixed16MiB documentation would weaken contract. No extra framework.

## Strengths and allegations not sustained

Pure host-global/native-free blocking embedding and transport handoff intact.
Guardian independently forks/signals/reaps workers; manager avoids stale worker
PID fallback. Supervisor20–37 preserves original TERM20/KILL10/retry1 deadlines,
no catch-up burst or repeated-abort reset. Old lockstep/snapshot allegation no
longer applies: independent control/liveness, sliced bulk and generation-bound
transfer/ack exist. Guardian validation, manager application and public commitment
are substantively distinct; consumption/generation protection remain useful.
No measured synchronous public encode/copy latency violation established, so not
reported as defect. Guardian death does not justify unsafe PID fallback/second
supervisor. Matrix timings remain reported evidence, not reviewer reruns.

## Historical baggage/evolutionary bias

Owner guarantees justify guardian/control/capacity/deadlines/single consumption.
Mirrored state, release route and completion predicate are implementation choices;
new repair distinctions need boundary reconciliation too. Fix specific scenarios,
retain architecture, do not revive expanded framework or another programme.
