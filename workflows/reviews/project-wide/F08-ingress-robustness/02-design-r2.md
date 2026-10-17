# Single ingress owner for outstanding request identities

Focused alternative adds local duplicate guards. Select one ingress-owned request
reservation registry, shared by all protocol/manager dispatch paths; no competing
manager registry for correlation. Internal ownership indexes may reference that
reservation, not independently decide client-ID uniqueness.

Duplicate of any outstanding request: JSON-RPC error -32600 Invalid Request,
response `id:null`; preserve the original reservation, operation and response.
This includes an original terminal evaluation whose response is not committed.
Decoded false/null/scalars are invalid-request -32600, whereas invalid JSON is
parse-error -32700. Do not use decoded-value truthiness to detect decoder failure.

Reserve only validated ID-bearing requests at ingress before tool dispatch.
Release when its complete response is successfully committed/enqueued, not at
execution termination or preview. A rejected ordinary admission request retains
its reservation until its error response commits. A malformed request rejected
before reservation owns none. Suppressed cancellation releases its reservation
once suppression and associated cleanup binding are committed; late result data
cannot complete a reused ID because execution generation stays separate.
Failed encoding must commit a fallback before release; failed enqueue/transport
closes the connection and clears all reservations through cleanup. Disconnect
clears them once. Later same-ID reuse after commitment/suppression is legal.

This is correlation safety, not a general dispatcher/compatibility abstraction.
