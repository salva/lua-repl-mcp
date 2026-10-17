# Priority control and bounded incremental payload transport

## Alternatives and selected topology

Interleaving current snapshot fragments is the focused alternative, but retains
control dependency on bulk framing and payload snapshots. Select a separate
bidirectional control socketpair and bidirectional bulk socketpair between
manager and guardian, plus the existing independent manager-only liveness pipe.
Guardian still exclusively spawns/signals/reaps workers. Replace the superseded
snapshot/dirty-mirror private protocol; no compatibility mode or dual authority.

Control records are allocation/generation/transfer-bound NDJSON, maximum 16KiB
each. They carry allocate/execute-intent/kill/cancel, ready/failure/exit summaries,
validated-completion summaries and result acknowledgements. User code/arguments,
values and diagnostic bodies travel on bulk, never on control. Bound pending
records by existing session/request admission, with at most 1024 queued records,
coalesced per-allocation disposal using the earliest original timestamp. Reserve
space to request disposal for every admitted allocation; reject ordinary intake
before consuming that reserve. A full required-control channel is fail-closed,
not permission for an unbounded queue or continued unsupervised execution.

Bulk packets contain a four-byte header-length prefix, at most 256 bytes of
ASCII JSON metadata, then at most 32KiB raw payload. Metadata binds allocation,
execution generation, transfer identity, offset, length and final marker. Validate
lengths before allocation, enforce aggregate transfer caps and contiguous offsets.
Packets can split UTF-8/JSON tokens: parsers retain bounded incremental state.
Only one payload transfer per direction is active; others queue admitted handles,
not encoded copies. Transfers progress round-robin at packet boundaries.

## Scheduling and ownership

Each loop services liveness, signals/control and timers before one bulk quantum:
at most 64KiB scanned/copied I/O and 256 container/node visits, with string/token
conversion also resumable at that byte budget. No whole-frame encode/decode,
large string escaping, concatenation or key sorting may monopolize a turn.
Use bounded incremental codec state for bulk/public wrappers; worker result bytes
may be forwarded from retained validated segments instead of re-encoded copies.
Control framing cannot be blocked by an unfinished bulk packet. A healthy system
qualification target is control receipt within 100ms under full legal load;
this is a measured scheduling allowance, not an OS real-time guarantee. Monotonic
deadlines still expire when next scheduled, without extending phases or bursts.

Guardian owns a bounded immutable result transfer until manager acknowledges
ownership after fully validating and recording it, or discards it on replacement/
disposal. Manager then owns the single-consumer payload. Bulk ACK transfers
ownership; public consumption independently releases manager data. A small
summary alone does not record manager completion (F13). Disposal may overtake a
partial transfer: mark its identity discarded, stop producing packets, and drain
already-buffered stale packets without applying them or reviving a session.
Bound stale drain by channel bytes/caps; lost framing is transport failure.

## Original deadlines and shutdown

Allocation timestamp/deadline originate at manager acceptance and accompany the
small allocation intent before bulk input. Guardian rejects expired intent
before OS spawn; readiness and implicit dispatch also recheck the original
deadline. A queued/partially transferred execution cannot start after disposal
or startup expiry. Guardian runs native deadline checks independently of bulk.

Disposal commands carry original accepted time and generation. Guardian signals
promptly on receipt, retries TERM through original+20s then KILL through
original+30s; no reset on handoff. Both manager and guardian enforce their
original wait/disposal bounds even if bulk never completes. Manager can close
bulk/liveness on control failure and report unconfirmed exit; guardian checks
liveness before every quantum. Distinguish child-disposal bound from draining a
slow client's response: no client flush is a prerequisite for worker cleanup.
Preserve observed outcomes and honest best-effort notices for scheduling/OS
failure. F13 defines exactly which partial result can survive destructive control.

Historical-baggage conclusion: separate bounded channels/events replace accidental
lockstep snapshots; they do not replace proven guardian ownership or enlarge caps.
