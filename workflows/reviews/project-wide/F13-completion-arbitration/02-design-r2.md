# Selected manager-authority model with deadline evidence

Select the focused model: manager owns logical outcome recording and destructive
request acceptance. Guardian alone provides generation-bound evidence that a
complete valid worker result was validated at monotonic time T before deadline H.
That evidence protects against a stale hard-timeout decision, but does not itself
record a public terminal result. Manager records completion only after complete
payload validation/application. Public response commitment later consumes once.

Alternative: guardian orders all completion/destructive commands and manager
awaits its decision. Not selected: it moves kill acceptance authority and adds
remote decision latency without a demonstrated owner need. The selected model
requires explicit clarification of SPEC §7 kill/completed preservation and
§14.6: 'recorded completion' means manager application; guardian validation is
deadline evidence. This removes ambiguity, not permission to rewrite an already
recorded result. Add matching public lifecycle guidance.

| Events | Required decision |
| --- | --- |
| Timely guardian validation, delayed/partial bulk relay, no destructive request | Keep deadline-eligible candidate; do not freeze a timeout solely from stale manager clock. Record completion only after full payload application. |
| Summary arrives before full payload | Update deadline evidence only; not result_available or logical completion. |
| Kill accepted before manager completion application, including timely guardian candidate | Freeze killed, destroy session, discard candidate transfer; late packets cannot undo it. |
| Cancellation accepted at that same boundary | Freeze cancelled, destroy session; suppress cancelled RPC response and resolve other already-bound waiters under fatal/single-consumer rules. |
| Manager recorded completion before kill/cancellation, response not yet committed | Preserve outcome for already-bound waiters; destroy idle worker/session. Cancellation still suppresses its own response without consuming payload; another eligible pending waiter may consume once. |
| Fatal disposal and expired wait still outstanding | Fatal decision wins over uncommitted pending reply (F04); already-committed pending reply is immutable. |
| Wrong/stale allocation, generation or discarded transfer | Ignore as stale without effects on new execution; malformed active records trigger that allocation's failure. |

F02 control summaries carry allocation, generation, transfer identity, complete
validation time and byte/depth facts. Bulk may arrive before/after its summary;
stage but never apply an incomplete candidate. Process control/disposal at safe
quantum boundaries before bulk continuation. ACK accepted payload only after
manager recording; otherwise discard and drain queued stale packets. A summary
cannot let an unvalidated payload overwrite killed state or claim values exist.
No terminal outcome is inferred from raw worker-code return or pipe EOF alone.
