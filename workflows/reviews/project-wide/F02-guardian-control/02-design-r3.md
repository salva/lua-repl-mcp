# Priority control and serial bounded bulk transport

Select separate manager/guardian bidirectional control and bulk socketpairs,
plus the independent manager-only liveness pipe. Interleaved legacy snapshots
are the rejected focused alternative: they retain large-frame gating. Guardian
alone spawns/signals/reaps; remove snapshot/dirty-mirror compatibility machinery.

## Channels, capacity and work

Control NDJSON records are at most16KiB and contain only bounded identities,
timestamps, statuses, lengths and body references. All input-sized code, args,
cwd/options, stream paths, ready cwd, file_created paths, diagnostic/offending
paths use bulk bodies, not control. Small allocate/ready/file-created/error
intents reference those bodies; no truncation or new16KiB public path limit.
An allocation must have its full validated creation-options body before spawn,
and recheck the original deadline then. Public file/path evidence is reported
only after its complete validated body is available; missing reports stay honest.

At construction derive record cap Q=max(1024,8*S+2*(O+C)), where S/O/C are validated
session/ordinary/control admission bounds. Reserve S slots exclusively for one
coalesced earliest-deadline disposal per allocation; ordinary traffic cannot use
them. Fixed event/body-reference and request lifecycles must respect the remaining
cap. Bound bytes by16KiB*Q, checked against the supported2147483647 internal
capacity ceiling before acquiring resources; reject incompatible configuration
then. Coalesce redundant polls/control intents, never required completion ordering.
No unbounded queue or late discovery that all disposal capacity was consumed.

Bulk packets use a four-byte header-length prefix (header<=256 ASCII JSON bytes)
then<=32KiB raw data, bound to allocation/generation/transfer/offset/length/final.
Choose serial FIFO transfers per direction: exactly one active parser/transfer;
other admitted transfers queue bounded handles, not copies. No round-robin or
interleaved transfer states. A discarded transfer ends at the next packet boundary;
drain queued stale packets by identity and then begin the next FIFO transfer.
Finite per-transfer caps prevent a healthy sender extending a transfer forever.

Every loop services liveness, signals, control and timers before one bulk quantum,
at most64KiB scanning/copying and256 container visits. String/token handling,
escaping, concatenation and wrapper parsing/serialization are resumable within
those bounds, not whole-large-frame work. No large atomic key sort is required
for private transfer. Validate offsets/caps before allocation. Qualify healthy
control latency<=100ms under legal load; this is scheduling evidence, not an OS
real-time promise. Monotonic deadlines never reset or cause catch-up bursts.

## Bodies, ownership and deadlines

Use F03's validated raw selected-field spans for inbound commands so original
legal input fits unchanged private floors; never re-encode expanded arguments
or forward an entire public envelope. Guardian validates command identities and
the same structural/body rules; worker decodes into fresh argument tables.
Creation/path/result bodies remain subject to existing worker/public/diagnostic
budgets and F05 bounded fallbacks, not the small control cap. Diagnostic loss is
flagged according to the public contract; creation-file knowledge is not invented.

Guardian retains immutable result segments until manager ACKs full validation/
logical application or discards after replacement/disposal. Manager then owns
single-consumer payload storage. Public consumption releases manager data, not a
second guardian snapshot. A small validation summary provides deadline evidence
only (F13); partial payload never records manager completion. Destructive control
can overtake it; stop producing, discard queued stale packets without application.

Startup origin/deadline are set at manager acceptance and carried in the small
intent. Reject expired intent before body-dependent spawn; recheck at readiness
and before implicit dispatch. A partial body cannot spawn with default options.
Guardian native deadlines run even with blocked bulk/report delivery.
Disposal carries original time/generation: TERM through+20s, KILL through+30s,
retry1s and abandon thereafter, no serial per-worker wait or handoff reset.
Manager's wait/shutdown bound is independent of bulk/client output drainage;
close failing channels/liveness and report unconfirmed exit honestly. Guardian
checks independent EOF each quantum. Preserve F13 recorded outcomes and F04
outstanding-wait behaviour. No extra topology or authority choice is deferred.

Historical-baggage conclusion: remove accidental lockstep snapshots while keeping
owner-required guardian ownership. Serial state is deliberately minimal; do not
turn bounded incremental processing into a generic streaming framework.
