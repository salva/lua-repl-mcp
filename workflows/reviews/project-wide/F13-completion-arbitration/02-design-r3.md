# Manager outcome authority and distinct cancellation semantics

Select manager logical authority, retaining guardian complete-valid-result time
only as hard-deadline evidence. Completion eligibility is not user-code return.
Manager records a result after full payload validation/application; public
commitment later consumes it. Reject the alternative of remote guardian kill
decision authority: it changes acceptance semantics without an owner need.
Clarify SPEC §7/14.6 'recorded completion' as manager application; keep §11.3's
already-explicit inert cancellation of completed requests unchanged.

| Events | Required outcome |
| --- | --- |
| Complete guardian validation before deadline, delayed relay, no destructive request | Candidate remains deadline-eligible; stale manager clock cannot invent timeout. Apply only after full payload validation. |
| Small summary or partial bulk only | Deadline evidence/staged candidate, not manager completion or available values. |
| Explicit kill accepted before manager completion application | Freeze killed, destroy session, discard partial/candidate payload. |
| Active request cancellation accepted before manager completion application | Freeze cancelled, destroy session, suppress that RPC response; other bound waiters resolve under fatal/single-consumer rules. |
| Explicit kill after manager completion recorded, before response commitment | Dispose idle worker/session; preserve recorded result for already-bound waiters, single consumption. |
| Cancellation after manager completion recorded, before response commitment | Inert: do not kill, suppress, consume or release reservation. Normal result/response and outstanding ID survive until commitment. |
| Fatal disposal and expired uncommitted wait | Deliver recorded fatal decision rather than pending running; already-committed pending responses remain immutable. |
| Stale generation/allocation/transfer | Never complete new execution; ignore discarded/stale packets, fail malformed active protocol locally. |

F02 summary includes allocation/generation/transfer, complete-validation time and
size/depth facts. Payload/summary may arrive in either order; neither incomplete
part records completion. Safe-quantum control processing may kill/discard a
candidate before full application, but cannot overwrite recorded completion.
ACK ownership only after application; discard stops production and drains queued
stale packets by identity. Suppression releases F08 reservation only for accepted
active cancellation, never the inert completed-request case. Preserve delayed-
relay deadline fix, completed-outcome immutability and truthful session disposal.

Historical-baggage conclusion: distinguish three concrete boundaries rather than
changing cancellation merely because kill and cancel share some cleanup code.
