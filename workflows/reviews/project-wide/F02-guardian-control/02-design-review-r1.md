# F02 design review

Required changes:

1. Select the actual topology now. 'Choose the simplest topology' leaves the central repair undecided. State channels, writers/readers, framing, priority scheduling, queue bounds, and the unit at which bulk traffic can yield. A separate socket alone does not bound a turn spent encoding/decoding an entire large frame.
2. Specify allocation/generation-bound result transfer and acknowledgement ownership: when the guardian may release payloads, how replacement/disposal handles partially transferred payloads, and which small lifecycle records can progress while bulk output is blocked. Do not retain the old snapshot/dirty-mirror protocol alongside an unspecified new path.
3. Specify startup and disposal timing end to end: original allocation origin, expiry before OS spawn, expiry before implicit dispatch, prompt signal delivery, and bounded manager shutdown when a report never completes. Distinguish worker disposal from client response drainage.
4. Integrate the selected F13 authority with control overtaking bulk traffic. Define how a completed lifecycle record and its not-yet-delivered payload are treated when kill/cancel arrives.

Both alternatives are plausible, but the implementer must not have to choose the architecture. Retain owner cleanup timing and capacities; no compatibility shim for the old private protocol is needed for this local release.

VERDICT: CHANGES_REQUESTED
