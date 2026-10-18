# Simplicity-first design review

Reviewer: fresh GPT-6 Astra (`openai/gpt-6-astra`), session
`ses_eb1e3795cffeno8qxGQSAC4Ueg`. Source verified at `a600754`; proposed plan at
`5cb83db`. This is a faithful condensed advisory receipt, not adopted requirements
or an experimentally qualified replacement. No edits, tests/native processes,
state, credentials, services or other agents used by reviewer. Static source:
20 Lua modules,2558 physical lines including two generated schema modules.

## Executive judgment

**Process architecture is justified; much recovery/representation machinery is
negotiable. Revise cycle2 before implementation.** Independent ownership, bounds,
identities and disposal are safety; seamless capacity replacement under blocked
bulk is availability, not safety itself. Prefer ordinary pre-admission rejection,
optional metadata omission and coarse safe failure over elaborate recovery.

Complexity is concentrated in overlapping ownership transitions/repeated data
preparation, not a sprawling module framework. Prior approval and preserving
every written guarantee are not substitutes for choosing a simple product.

## Ranked simplifications and tradeoffs

### 1. Reject allocation until existing internal credit is reusable

Evidence: [manager.lua:225](../../../../lua_repl_mcp/manager.lua#L225)–237;
[guardian.lua:79](../../../../lua_repl_mcp/guardian.lua#L79)–84,102,293–296,324–325.
Current independent death frees public capacity before bulk release retires old
allocation. Do not automatically add another retirement/ack/stale-record protocol.
Account outstanding internal allocations at admission and return temporary
capacity error **before accepting/spawning** replacement. Existing ordered bulk
can keep release-before-replacement ordering. Rejection simpler than deferral,
which adds pending lifecycle/startup-clock state.

**Owner decision:** permit a listed-dead session's capacity to remain unavailable
while bulk blocked. Cleanup must still progress independently; immediate capacity
reuse need not. Do not silently preserve the prior plan's stronger availability
requirement. Documented manager-wide fail-stop can handle broken internal
invariants, but routine capacity contention should reject, not destroy others.
Safety requires bounded ownership, not seamless replacement.

### 2. Challenge result acknowledgement retention

Evidence: [guardian.lua:46](../../../../lua_repl_mcp/guardian.lua#L46)–51,120–133,316–322;
[guardian_channel.lua:10](../../../../lua_repl_mcp/guardian_channel.lua#L10)–38.
No reconnect/retry delivery protocol exists; channel failure already fails closed.
Consider transferring result reference to bounded outgoing report, then freeing
allocation's duplicate reference. Queue owns record during encoding/bytes during
send; manager owns complete validated result. Generation/public commitment remain.

Potential reduction: ack message family/traffic and ack-controlled retention.
Validate actual reference ownership before removal; this is a candidate, not a
proven safe patch. Do not turn it into prerequisite rewrite or promise recoverable
delivery that current implementation does not supply. Public consumption is not
the same as private handoff and must stay correct.

### 3. Omit inconvenient optional error paths

Evidence: [codec.lua:21](../../../../lua_repl_mcp/codec.lua#L21)–25,136–144;
[evaluator.lua:50](../../../../lua_repl_mcp/evaluator.lua#L50)–54;
[errors.lua:37](../../../../lua_repl_mcp/errors.lua#L37)–39.
Choose exceptional oversized-path omission, conservative encoded allowance.
No ancestor search, pointer truncation, repeated fit encodings or budget framework.
Keep completed result_serialization_error and side-effect warning. If giant initial
pointer allocation matters, stop optional detail past internal bound locally.

**Owner decision for broader reduction:** removing normal pointers changes SPEC
§14.9 location guidance. Likewise replacing exact invalid/truncated flags with
coarse sanitized/shortened indication could stop full-tail diagnostic scanning,
but changes diagnostic precision. Do not silently change either contract.

### 4. Remove repeated preparation before cooperative safety

Evidence: [protocol.lua:43](../../../../lua_repl_mcp/protocol.lua#L43),86;
[codec.lua:9](../../../../lua_repl_mcp/codec.lua#L9)–15;
[worker_protocol.lua:46](../../../../lua_repl_mcp/worker_protocol.lua#L46)–83;
[guardian.lua:233](../../../../lua_repl_mcp/guardian.lua#L233)–245;
[worker_supervisor.lua:101](../../../../lua_repl_mcp/worker_supervisor.lua#L101)–115;
[contracts.lua:48](../../../../lua_repl_mcp/contracts.lua#L48),56–65.
Small private trusted-boundary entrypoints can remove duplicate decode/validation/
depth walks. Keep actual public/worker-response validation and fresh snapshots;
no generic validated-object framework. Optional F08 deletion useful if simple.

**Owner decision:** canonical-only input accounting or rejection when internal
representation cannot fit could remove original-request token/dual representation.
It changes accepted inputs. Under current large-byte/progress guarantees, blindly
removing cooperative checkpoints can block guardian cleanup; byte-bounded is not
latency-bounded. Safe fail-stop cannot interrupt synchronous guardian computation.

### 5. Reduce supported configuration/precision, not add dynamic recovery

Evidence: [limits.lua:42](../../../../lua_repl_mcp/limits.lua#L42)–69;
[SPEC.md:1099](../../../../docs/SPEC.md#L1099)–1148;
[protocol.lua:12](../../../../lua_repl_mcp/protocol.lua#L12)–38.
Seven interacting limits and exact coupled floors enlarge supported combinations.
Keep current defaults/floors immediately; **owner-choice** fewer knobs/profiles
could reject unsupported combinations at construction. No covert depth minimum or
capacity reduction. F06 needs only fixed schema bound, not schema-depth engine.
Structured+text compatibility copy is another optional product-policy cost, not
automatically removable. None of these suggestions authorize compatibility change.

### 6. Fail worker/connection rather than salvage incomplete results

Evidence: [worker_supervisor.lua:234](../../../../lua_repl_mcp/worker_supervisor.lua#L234)–255;
[SPEC.md:1237](../../../../docs/SPEC.md#L1237)–1254;
[client_transport.lua:157](../../../../lua_repl_mcp/client_transport.lua#L157)–175.
**Owner-choice:** preserve only completely validated result at worker death;
otherwise fail with possible effects and discard partial tail. Unrecoverable
response encoding may fail connection with owned-worker cleanup rather than retain
result for later retrieval. Removes late-drain/salvage/overflow-retention states,
but loses recoverable results in races. No automatic retry of side-effecting code,
no rewriting recorded completion as not_started, no wrong-request cancellation.

### 7. Keep justified small public APIs/tools; stop campaign accumulation

Preview/commit protects single consumption; handler handoff protects host-owned
transport. Create/execute/wait/list/kill is coherent for persistent async sessions.
Removing it is product redesign. Small schema generator avoids handwritten
duplication. External containment protects actual test failures. Keep these;
retire obsolete expected-red demonstrations from ordinary acceptance if no longer
protecting supported behaviour. No new matrix/generator/review framework.

## Cycle2 plan disposition

| Local item | Simplicity-first direction |
| --- | --- |
| F01 resolved cancellation | Keep small predicate correction. Coarse failure does not excuse ordinary stale cancel destroying another execution. |
| F02 retirement | Prefer pre-admission temporary rejection; new handshake only if owner explicitly needs bulk-independent replacement. |
| F03 guardian reap | Essential bounded ownership; closed descriptors are not child reap. |
| F04 metadata | Small oversized-path omission, no ancestor framework. |
| F05 admission/global dataflow | Fix local variables/propagation; retain current accounting unless owner changes it. No freely supplied bypass. |
| F06 discovery | Small fixed-content allowance, independent user bound. |
| F07 overlap oracle | One targeted test asserting chosen replacement policy, not obsolete seamless replacement expectation. |
| F08 duplicate walk | Optional local deletion with D/D+1 check; no release project. |

Exceptional unreaped ownership in worker_supervisor258–271 must remain bounded.
If OS prevents disposal/reap, stop admitting work rather than silently drop child
ownership or add another recovery supervisor. Report exceptional uncertainty.

## Smallest sufficient architecture and revised sequence

Keep pure host handler/evaluator; bounded connection manager with immutable IDs,
one execution/retained outcome per session; independent guardian owning spawn/
signal/reap; bounded frames and independent cleanup control/liveness. Malformed
worker traffic destroys that worker; broken guardian transport safely ends the
connection and cleans owned workers; ordinary overload rejects before dispatch.
Small truthful errors, optional detail omitted, no execution retries.

1. Obtain owner decisions on temporary allocation rejection, coarse fail-stop,
   and any desired input/configuration/salvage relaxations.
2. F01/F03 and simplified F02 accounting; no new retirement machinery by default.
3. F04 omission/F05 local dataflow/F06 fixed schema allowance; optional F08 only
   if straightforward. Evaluate ack removal separately, not a prerequisite rewrite.
4. Essential tests: stale-cancel/single consumption, blocked bulk/kill/replacement
   chosen policy, owned reap/bounded unknown exit, metadata completed/effects,
   admitted-input/depth1, schemas and one installed/client integration.

No whole-module removal established. Defensible candidate reduction: one ack
family, avoided retirement handshake, one redundant recursive walk. Owner-approved
changes could also remove original-token/dual representation and post-exit salvage.
No reliable net LOC estimate without implementation design.

## Historical baggage and limits

Review-prescribed acknowledgements, original forwarding, completion boundaries and
wrapper accounting created interactions now needing repair. Earlier choices solved
real contracts but their availability/precision guarantees should be reconsidered,
not inherited automatically. Conversely safety is not optional because code is
long. This report is source/static reasoning, not qualified ownership replacement.
No new requirement, code change, fixer or Saivage resume is authorized by it.
