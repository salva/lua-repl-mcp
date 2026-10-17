# Lua REPL over MCP — Specification

Status: initial functional specification.

## 1. Objective

Provide a Lua module implementing a persistent REPL accessible through the Model
Context Protocol (MCP). An MCP client, including an LLM agent, submits Lua code,
the code executes synchronously, and the client receives its output, returned
values, or errors.

The project must support both standalone sessions and integration into existing
applications embedding Lua. The sibling project `../dosbox-y` is a motivating
integration target; compatibility with its actual embedding API must be verified
before defining that integration.

## 2. Components and independence

### 2.1 Session manager

The session manager creates, tracks, and closes standalone sessions, using the
session handler for REPL execution. It exposes session lifecycle operations
through MCP.

Each standalone session has its own persistent Lua state. Separate sessions must
not share Lua globals by default. Full system access means they are not isolated
from shared filesystem, process, or other operating-system resources.

Each managed session runs in its own Lua interpreter process, connected to the
manager through private pipes or a socket. The manager reuses the independent
session handler in each worker. Embedded integrations do not require a worker
process: they use their host's existing interpreter directly.

The manager owns the lifecycle of the standalone sessions it creates and may
dispose of their interpreters when those sessions are closed.

### 2.2 Session handler

The session handler implements the REPL within a Lua interpreter. It must be
usable independently of the session manager, including inside custom host
applications. Embedding it must not require starting the standalone manager or
launching a separate interpreter.

In embedded use, execution occurs directly in the host's existing Lua global
environment, not in a sandbox or a separate environment that hides the host's
state. Host APIs and live application state are directly accessible. Definitions
and mutations made by REPL execution remain visible to the host.

The host retains ownership of its interpreter. The handler must not implicitly
destroy or reinitialize that interpreter when a connection ends or a reset or
close is requested.

MCP framing and transport concerns must remain separable from code evaluation
and lifecycle policy. A custom integration may supply its own transport and
lifecycle handling without depending on the manager.

## 3. Execution model

Each session handler is **blocking and single-threaded**. The manager uses a
single-threaded I/O event loop to multiplex independent worker processes.

- The module must not create background threads.
- A request executes synchronously on the thread invoking the handler, subject
  to the host's thread-affinity requirements.
- Only one evaluation may be active in a given interpreter at a time; concurrent
  or reentrant evaluation is not supported.
- A handler's execution response is sent after execution finishes, if its
  connection is still available. The manager may return an earlier pending status
  to its client as specified in section 7.2.
- The handler does not service additional MCP requests, pings, progress updates,
  or cancellation notifications while code is executing.
- A long-running execution in one managed session must not block the manager
  from routing requests and responses for other sessions.
- Requests within a session execute sequentially. Different managed session
  processes may execute concurrently; this requires no threads in a handler or
  embedded host.
- No external bridge or cooperative polling API is required for embedded use.

Blocking applies to an individual execution and may also apply to the hosting
REPL loop. A returning execution must not be confused with the termination of
the REPL session.

## 4. Persistent REPL behaviour

The handler must accept Lua statements and provide a documented way to evaluate
expressions and retrieve their values. The exact expression-entry convention is
an implementation decision.

Globals and globally reachable functions and objects persist between requests.
Ordinary chunk-local variables follow Lua's normal scoping rules; the REPL does
not promise to preserve lexical locals between separately compiled chunks.

Execution results must distinguish:

- Successful execution, including zero or more returned values.
- Syntax or compilation errors.
- Runtime errors, with diagnostic context where available.
- Output captured during execution, including output preceding a runtime error.

Ordinary Lua errors must not end an otherwise usable session. Errors do not roll
back changes already made to Lua state or external resources.

Multiple return values and `nil` positions must be represented without losing
their number or order. Values that cannot be represented directly in JSON,
including functions, userdata, and cyclic tables, must have a safe, documented
representation. Arbitrary Lua objects need not be serializable or round-trippable.

The output-capture contract must be documented. At minimum, ordinary Lua `print`
output must be included in execution results. Capturing native-library output,
subprocess output, or every possible direct stream write is not assumed.

For stdio MCP, protocol output must not be mixed with captured REPL output.
Transport handling must document the limits of this guarantee when full-access
code deliberately writes directly to protocol streams.

## 5. Access and trust model

The initial version provides **full access**, with no sandbox.

- Standalone execution has access to the Lua libraries and facilities available
  in its configured interpreter, including filesystem access, process execution,
  and native module loading where supported.
- Embedded execution has the capabilities available in the host's interpreter,
  including application-provided APIs. The module need not add libraries the
  host has deliberately omitted.
- Executed code has the privileges of the hosting process. It may mutate host
  state, interfere with the handler, terminate the process, or crash native code.
- Only trusted clients and trusted code should be allowed to execute.

Restricted environments, capability allowlists, containers, and OS sandboxing are
outside the initial scope. Full access is not a security boundary between
sessions, between the REPL and the host, or between the client and the server.

Any network-accessible deployment must explicitly address authentication and
exposure; the choice of transport and deployment security is still open.

## 6. Lifecycle and host control

The integration must distinguish normal request completion from REPL termination
and explicit lifecycle requests.

When a blocking REPL invocation returns, it must provide enough structured
information for the host to decide what happens next. Relevant reasons include:

- Client disconnect or transport end-of-input.
- Explicit session-close request.
- Explicit reset request, when supported by the integration.
- Unrecoverable handler or transport error.

A syntax or runtime error in submitted Lua code is an execution result, not
automatically an unrecoverable handler error.

Reset and close are application-level lifecycle operations, not assumptions
about standard MCP protocol methods. Exact tool names and wire schemas remain
to be defined.

For embedded use, the host may keep the Lua state, reset it, or terminate the
interpreter or application. The handler must convey the reason and relevant
request context; merely returning without a reason is insufficient to distinguish
these policies. A custom host may intentionally treat REPL termination as the
point at which it resets or shuts down.

For standalone sessions, `session_kill` releases manager-owned session resources,
whether the session is idle or executing. No separate `session_close` tool is
required.
A reset operation must be available to obtain a fresh standalone REPL state;
whether it preserves the session identifier remains an API design decision.

The implementation must define response and handoff ordering for lifecycle
operations so the host knows whether a response has already been sent before it
performs destructive cleanup.

## 7. Long-running operations, timeouts, and cancellation

There is no guaranteed keep-alive or progress reporting during execution.
A long-running Lua loop or blocking native host call can prevent the handler
from servicing MCP for the entire duration of that operation.

For managed sessions, the manager's event loop remains responsive while a worker
executes. This does not mean the worker can report progress or process
cancellation during execution, and does not remove client request deadlines.

MCP connection health and request timeouts are separate concerns. Even where
supported, a heartbeat does not guarantee that a client will continue waiting.
Clients may extend request timeouts after progress notifications, but are not
required to, and may enforce an absolute deadline.

Consequently:

- Deployments must configure client request timeouts for their expected workloads.
- The initial version does not promise safe interruption of arbitrary Lua or
  native host operations.
- A cancellation or disconnect occurring during execution may not be observed
  until execution returns.
- Client timeout, cancellation, or disconnection does not imply execution stopped
  or its side effects were undone.
- An infinite loop or permanently blocked native call may require external host
  intervention. Full system access does not make forced interruption safe.
- Clients must not automatically retry a timed-out state-changing execution on
  the assumption that it did not run.

### 7.1 Manager-enforced execution timeouts

Managed execution requests may specify an execution timeout. The manager owns
worker process creation, supervision, and termination, and enforces the timeout
using its event loop independently of the worker's Lua execution.

The timeout starts when execution is dispatched to the worker, not while a
request is waiting in a session queue. If execution has not completed before
the deadline, the manager must forcibly terminate the worker, reap the process,
and report an execution-timeout failure to the client. It must not rely on the
blocked handler to acknowledge cancellation or voluntarily stop. Other managed
sessions must remain available during timeout handling.

This kills the session's interpreter process, not the MCP client or manager.
The session becomes terminated and its in-memory Lua state is lost. Subsequent
executions must fail for that session rather than silently creating a fresh
interpreter. Other pending requests for the terminated session must also be
resolved as failures.

Process termination does not roll back filesystem changes or other external
side effects, permit graceful host cleanup, or guarantee termination of spawned
descendant processes. Timeout handling must document those limitations.

This server-enforced execution timeout is distinct from a client's own MCP
request deadline. A client-side timeout alone does not request or guarantee
worker termination. Timeout field names, units, permitted bounds, and any
default when omitted remain API decisions.

Embedded handlers do not kill their host application to implement this feature.
They must reject requests requiring this enforced timeout unless the host
explicitly provides an equivalent enforcement policy; they must not silently
claim that a hard deadline can be enforced by a blocked single-threaded handler.

If progress reporting is added later, MCP progress notifications must use a
client-supplied progress token and satisfy the negotiated protocol's rules.
Fabricated percentages must not be used as keep-alives.

### 7.2 Unified synchronous and asynchronous execution

The manager must expose all three client waiting modes through one execution
tool. This specification calls the parameter `wait_timeout_ms`:

| Value | Behaviour |
| --- | --- |
| `null` | Wait for execution to finish and return its terminal result. |
| `0` | Accept execution and return its session ID and pending status without waiting for completion. |
| Positive number | Wait up to that many milliseconds; return a terminal result if available, otherwise return the session ID and pending status while execution continues. |

The field's omitted-value default and whether fractional milliseconds are
accepted remain schema decisions. Negative, non-finite, and otherwise invalid
values must be rejected before execution starts.

The public API uses `session_id` for all execution and lifecycle operations;
there is no public `task_id`. Session creation returns the session ID, session
listing includes it, and all subsequent session-scoped tools accept it.

`session_execute` also accepts `session_id: null`: the manager allocates a fresh
session and dispatches the supplied code to it in the same tool call. Explicit
preallocation with `session_create` remains available but is not required.
Auto-created sessions have the same persistence, ownership, timeout, and cleanup
semantics as explicitly created sessions; completion does not dispose of them.
Every accepted execution response includes the actual allocated session ID,
whether pending, successful, or failed, so the client can reuse, wait on, or kill
that session. Allocation failure must be reported without claiming execution
started. Validate execution parameters before allocating a worker.

Null means allocation only for execution, not an implicit current-session alias
or a wildcard. Wait, kill, and reset require a concrete session ID and must not
allocate workers as a side effect. The behaviour of an omitted `session_id`
remains a schema decision; explicit null must be supported.

JSON-RPC request IDs correlate protocol requests and responses, not executions.
A response identifies the session and whether its execution is pending or
terminal. If the wait expires, the manager must return control without cancelling,
restarting, or resubmitting the execution. The client can subsequently poll that
same session for status and retrieve its terminal result, including output or errors.
The final result must remain retrievable even if completion races with returning
the pending response. Status and result retrieval must not execute the code again.

The wait deadline starts when the execution is dispatched. The manager must
continue servicing other requests while waiting. Expiry releases only the
client's wait; the worker continues and its session remains busy until execution
terminates. The handler remains blocking and single-threaded regardless of the
client's waiting mode.

The wait timeout is distinct from the optional hard execution timeout in section
7.1. Both may apply to one task: a client can wait five seconds for a result while
allowing execution to run for at most ten minutes. Only the hard execution
deadline triggers worker termination and state loss. A null wait timeout does
not disable a supplied hard execution deadline or a client's own MCP deadline.

Task polling and retained-result retrieval are application-level MCP tools in
the initial contract; they must not be presented as standard MCP Tasks support
unless that optional protocol feature is separately implemented and negotiated.
These manager facilities do not require a standalone embedded handler to service
requests while executing.

Task status must distinguish pending execution from success, failure, and
interruption. Polling responses must make clear whether the session remains
usable after termination. Exact status names, tool schemas, result-retention
limits, and expiry behaviour must be defined before implementation.

### 7.3 Reattaching to a task: wait

The manager must expose a `session_wait` tool taking `session_id` and
`wait_timeout_ms`, with the same null, zero, and positive-value semantics as the
execution tool. Null waits for a terminal result; zero polls immediately; a
positive value waits for at most that duration before returning a pending status
if execution is still active. Each wait deadline starts when that wait is accepted.

Waiting reattaches to the session's current execution, never dispatches another execution,
and never resets or extends its hard execution deadline. Expiry of a wait does
not kill the task. Waiting on an already terminal task returns its retained
result immediately. Result retrieval is repeatable during the retention period,
not a destructive consume operation. Unknown sessions, expired results, and
sessions without an execution produce explicit, distinguishable errors.

Each session exposes at most one current execution and its result. Starting a
new execution replaces the previous retained result; reset clears it. Historical
executions cannot be addressed through this API. A pending wait is internally
bound to the execution current when the wait was accepted, so a later execution
or reset cannot substitute a different result for that waiter. Internal generation
identifiers may be used for this purpose but are not client-facing task IDs.

The manager remains responsive while a wait is pending, including to a kill
request for the same task. A task ending through success, failure, hard timeout,
or explicit kill resolves its pending waits with the corresponding terminal
outcome. This tool also provides polling and result retrieval; separate tools
for those functions are not required initially.

### 7.4 Terminating a session: kill

The manager must expose a `session_kill` tool taking `session_id`. It terminates
and reaps the session's worker and releases its private transport whether the
session is executing, idle after execution, or newly allocated with no execution
yet. Any running execution is marked killed. The response reports that the
session has terminated and lost its in-memory state. This tool serves both
execution interruption and ordinary session disposal; there is no separate close
tool. This is an explicit destructive operation, not cooperative Lua
cancellation. The cleanup and side-effect limitations of section 7.1 apply.

Kill targets the session worker present when the kill request is accepted.
If execution has already completed, its result is not rewritten as killed, but
the idle worker is still terminated. A session need not have executed any code
to be killed. Repeated kills of an already terminated session return its terminal
session status without further side effects while that status is retained.
Unknown session IDs produce an explicit error.

Because selection is by session, a delayed kill received after a new execution
starts targets that new execution. Clients must coordinate execution and kill
requests accordingly; the API cannot express "kill only an older run". Once a
kill is accepted, cleanup must be internally bound to the selected worker so it
cannot subsequently kill a replacement worker after reset or another execution.

A successful kill response must not claim termination before the manager has
confirmed worker exit. Requests waiting for the task must resolve consistently
with its recorded terminal outcome. Failure to terminate a worker must be
reported, not presented as successful cleanup. Other sessions remain available.

Both task tools are manager facilities; they do not require an embedded handler
to implement background execution or to kill its host.

### 7.5 Listing sessions

The manager must expose `session_list`, with no session ID required. It returns
a snapshot of the sessions owned by the current manager connection, including
both explicitly allocated and automatically created sessions.

Each entry includes its concrete `session_id`, session lifecycle status, and
current or latest execution status (or no execution yet). The response must
distinguish idle sessions, running sessions, and retained terminated sessions,
and indicate whether a terminal execution result is still available through
`session_wait`. Listing must not create sessions, execute code, or consume results.

The manager must answer listing requests while workers are executing. An empty
manager returns an empty list. Terminated entries may be removed according to
the documented metadata/result retention policy; they must not appear usable.
Exact status names and any pagination remain schema decisions.

## 8. Initial acceptance criteria

1. A client defines a global and a function, then uses both in a later request.
2. A client receives captured `print` output and returned values, including
   multiple values with intervening `nil` values.
3. Syntax and runtime errors are reported, and a later request still succeeds.
4. An embedded integration uses the handler without the manager and accesses and
   changes the host's existing globals and APIs.
5. Returning from an embedded REPL reports its termination reason without
   automatically resetting or destroying the host interpreter.
6. A custom host can use that reason to perform its own reset or shutdown.
7. The manager creates independent standalone Lua states and closes resources it
   owns; standalone reset produces a fresh state.
8. Execution uses no module-created background threads and respects the invoking
   host thread.
9. Long-running execution returns a result when it completes and the client is
   still connected; documentation clearly describes timeout and cancellation
   limitations rather than promising keep-alives.
10. MCP protocol messages remain separate from normally captured REPL output.
11. Multiple managed sessions share one client-facing MCP connection, with
    responses correlated by JSON-RPC request ID and executions routed by session
    ID. A long execution in one session does not prevent another session from
    executing and returning its result.
12. A managed session calling `os.exit()` ends its worker, not the manager. The
    manager detects worker exit and resolves affected pending requests as failures
    rather than leaving them waiting indefinitely.
13. A managed execution exceeding its supplied timeout causes the manager to
    kill and reap that worker, report a timeout, and mark the session terminated.
    Another managed session remains usable. An execution completing before its
    deadline does not cause its worker to be killed by a stale timer.
14. One execution tool supports null, zero, and positive wait timeouts. Expiring
    a wait returns the session ID without killing the worker or executing code twice;
    polling that session later yields the result and preserved session state.
15. Async execution returns the session ID without waiting for the worker's result.
    Completed results remain retrievable across the wait-to-poll transition.
16. A client reattaches with `session_wait`, can poll or wait with a fresh wait
    timeout, and retrieves the same result repeatedly without re-execution.
17. `session_kill(session_id)` disposes of newly allocated, idle, or running
    sessions; pending execution waits resolve as killed. Repeating the kill
    without reset has no further side effects. Accepted kill cleanup never
    targets a replacement worker.
18. `session_execute` with a null session ID allocates a fresh persistent session
    and returns its concrete ID in synchronous, asynchronous, and wait-expired
    responses, including execution-error outcomes. A later execution can reuse
    that ID and its state. Wait and kill reject null rather than allocate sessions.
19. `session_list` reports explicitly and automatically created sessions and
    their statuses without blocking on a running worker or consuming results.
    A manager without sessions returns an empty list.
20. JSON arguments convert automatically to Lua values and are passed through
    chunk varargs. Nested nulls and positional null arguments retain their
    positions through a documented sentinel, without source-code interpolation.
21. Ordinary Lua errors return diagnostics and available prior output without
    terminating the session. Worker exit or premature internal transport closure
    instead resolves pending executions and waits as failures and marks the
    session terminated; unrelated sessions remain usable.

## 9. Lua version support

Target **PUC-Rio Lua 5.4 and newer (5.4+)** for standalone and embedded use.
Lua 5.4 is the minimum supported version and the initial integration test target.
This matches `dosbox-y`:
its `configure.ac` enables the embedded debugger with Lua 5.4 and explicitly
checks `LUA_VERSION_NUM == 504`.

The session handler must be implemented in Lua, without requiring a native
component supplied by this project. It must work inside the host's existing
interpreter without introducing a second Lua runtime. Native APIs already
exposed by the host remain accessible, as do native modules available to
full-access user code; neither implies a native implementation of the handler.

The core handler must be tested with Lua 5.4, including execution inside an
existing host-owned interpreter. Dependencies must support that baseline and
must not unnecessarily restrict newer Lua versions. Maintain compatibility with
newer stable releases and document the versions actually tested, along with any
known incompatibilities. Untested future releases are a compatibility target,
not a guarantee against upstream breaking changes.

Lua 5.1, 5.2, 5.3, and LuaJIT are outside the initial support scope;
compatibility shims for those runtimes are not required.

## 10. MCP transport and supplied I/O

### 10.1 Independent session handler

The handler must support a host-supplied bidirectional socket or a pair of input
and output file descriptors. It must not require opening a listener, creating a
connection, or launching the manager.

Because standard Lua has no portable API for arbitrary sockets and file
descriptors, the pure-Lua handler accepts a host-supplied I/O adapter wrapping
those handles. The adapter provides read and write operations and, where
appropriate, an explicit close operation. Integration with host-specific handles
belongs in the adapter, not in the REPL evaluator.

The adapter contract must define partial reads and writes, end-of-input, and I/O
errors. It must work with byte streams without assuming that one read equals
one complete MCP message. Handle ownership must be explicit: borrowed handles
must not be automatically closed by the handler. Interpreter ownership remains
independent of transport ownership.

Message framing must be separate from the underlying stream. The initial stream
framing is MCP's stdio-style newline-delimited JSON-RPC: each message occupies
one line, with embedded newlines escaped within JSON strings. This framing may
also be used over supplied sockets or FD pairs by agreement with the peer; such
connections are custom transports, not automatically standard MCP transports.

### 10.2 Standalone session manager

The initial manager uses the standard MCP **stdio transport**. An MCP client
launches the manager and communicates through its standard input and output.
Protocol messages must be the only content on standard output; manager
diagnostics must use standard error or another non-protocol destination.

One manager MCP connection exposes session creation, execution in an identified
session, and lifecycle operations. Creating a Lua session does not require a new
MCP connection. MCP connection/session identity must not be conflated with the
identity of a managed Lua REPL session.

All client-facing requests and responses are multiplexed through that single
stdio connection. A session identifier selects the target Lua session; a
JSON-RPC request identifier correlates each response with its request. Responses
for different sessions may arrive out of request order.

The manager uses nonblocking I/O or equivalent event-loop facilities to service
the client connection and each worker's private transport without waiting
synchronously for an execution result. Partial messages or a busy worker must
not stall unrelated sessions. The worker transport is internal and does not
require the client to establish another MCP connection.

Killing a managed session terminates its worker and releases its private
transport. Resetting replaces the worker with a fresh interpreter. The manager
must detect worker termination, report affected request failures, and remain
available for other sessions. Process separation protects against ordinary
worker exit but is not a sandbox against full-access code deliberately affecting
the manager or other processes.

Streamable HTTP is a possible future standard transport for independently
running or remote deployments, but is not required initially. Unix-domain
sockets and raw TCP remain possible custom integrations through the supplied
I/O adapter; the initial manager need not listen on either. Legacy HTTP+SSE
transport is not required.

## 11. Proposed decisions for review

This section contains recommendations, not yet accepted requirements. Resolve
these policies before implementation rather than letting them emerge accidentally.

### 11.1 Public tool surface and code entry

Manager tools include `session_create`, `session_list`, and `session_execute`;
`session_reset` remains proposed. Required execution-control and disposal tools are
`session_wait` and `session_kill`, as specified in sections 7.3 and 7.4. All
session-scoped tools use `session_id`, not a separate task identifier.
The single execution tool implements all waiting modes in section 7.2 rather
than separate synchronous and asynchronous tools. A directly embedded handler exposes
execution and only those lifecycle operations the host supports; it does not
pretend to create or manage independent host interpreters.

Propose execution takes a complete Lua chunk, with explicit `return` for results.
This supports both statements and expressions without automatic expression
detection or a multiline interactive input protocol. For example, `x = 7` sets
a global and a later `return x * 2` returns its computed value.

### 11.2 Busy sessions and lifecycle operations

Propose rejecting another execution with a `session_busy` tool error while that
session is running, rather than maintaining a request queue. Other sessions
remain available. Kill and reset must remain actionable while a worker is busy;
either operation terminates the active worker and resolves its pending execution
as interrupted. Reset preserves the logical session ID but starts fresh Lua state.

### 11.3 Timeout and cancellation policy

Propose an optional positive integer `execution_timeout_ms` on managed execution,
separate from `wait_timeout_ms`. When
omitted, execution has no manager-imposed deadline; client deadlines still apply.
Use a monotonic clock and define completion as the manager receiving a complete,
valid worker response before the deadline. Disarm the request's timer on
completion so it cannot later kill an idle or replacement worker.

Propose explicit MCP cancellation of an active managed execution terminates its
worker, using the same state-loss policy as an execution timeout. Cancellation
must follow MCP response rules rather than promising a normal tool response to
a request the client has cancelled. This is distinct from a client merely
stopping its wait without notifying the manager.

### 11.4 Connection ownership and shutdown

Propose managed sessions are owned by the manager's stdio connection. End-of-input
or manager shutdown terminates and reaps all owned workers; reconnecting does not
restore their state. No detached sessions, persistence to disk, or automatic
recovery of interpreter state is required initially.

Embedded disconnect handling remains host-owned as specified above.

### 11.5 Results, errors, and resource bounds

Propose execution results include captured output, an ordered list of typed
return values, and structured error information when execution fails. Represent
Lua `nil` explicitly instead of relying on sparse JSON arrays. Render complex
objects with bounded inspection rather than evaluating arbitrary serialization
code. Document handling of binary strings, invalid UTF-8, non-finite numbers,
cycles, and metatables before finalizing the result schema.

Define configurable limits for input messages, captured output, value-rendering
depth and size, and managed session count. Prefer truncating diagnostic output
with an explicit truncation indicator to unbounded buffering. Worker output must
continue to be drained or otherwise handled after a capture limit is reached so
a full pipe does not deadlock execution. Transport corruption and worker crashes
must be distinguished from ordinary Lua runtime errors.

### 11.6 Platform and dependency boundary

The pure-Lua handler and host-supplied I/O adapter do not imply the standalone
manager can use only standard Lua libraries: standard Lua does not provide the
required portable process supervision and nonblocking descriptor APIs.

Propose Linux/POSIX as the initial manager platform, allowing an established
OS/event-loop dependency with native bindings if needed. This must not become a
required dependency of the embeddable handler. Windows manager support and
robust descendant-process cleanup require separate explicit decisions.

## 12. Task input data

`session_execute` accepts an optional JSON `args` array, defaulting to an empty
array. Each element becomes one positional argument to the submitted Lua chunk,
accessible through `...`. Conversion is automatic; callers need not encode JSON
inside the code or explicitly decode it in Lua.

| JSON value | Lua value |
| --- | --- |
| Boolean | Boolean |
| Number | Integer or float, where representable |
| String | String |
| Array | Table with consecutive 1-based integer keys |
| Object | Table with string keys |
| `null` | A documented, stable null sentinel, distinct from Lua `nil` |

Conversion applies recursively. Null object members and array elements must
not disappear, create holes, or shorten the positional argument list. The
sentinel must be accessible to submitted code through a documented API so code
can identify nulls. Exact naming remains an embedding/API design decision and
must avoid silently overwriting host globals.

For example, code `local person, count = ...; return person.name, count * 2`
with `args: [{"name": "Alice"}, 21]` receives a Lua table and a number and
returns `"Alice"` and `42`.

Arguments are transferred as data, never interpolated into Lua source. Each
execution receives freshly converted argument tables; retaining them in globals
is subject to ordinary session persistence. JSON provides no shared object
identity or cycles in input. Conversion must not silently round an integer to a
different value; numeric range/precision errors must be reported or handled by
an explicitly documented exact-number convention. Strings follow JSON's Unicode
semantics; arbitrary binary input needs a separately specified encoding.

Empty arrays and objects both become empty Lua tables; preserving their original
JSON shape on return is not implied. The result encoding remains to be finalized.
Whether execution returns synchronously or is retrieved with `session_wait`,
the terminal result representation must be the same.

## 13. Errors and worker failure

### 13.1 Recoverable Lua errors

Compile submitted chunks with error reporting and execute them through a
protected Lua call, such as `xpcall`. Distinguish syntax/compilation failures
from runtime failures. Report a safe error description, a traceback where
available, and captured output produced before failure. Lua may throw values
other than strings; diagnostic formatting must handle them without assuming
arbitrary user-defined conversion routines will succeed.

An ordinary Lua error produces a failed execution result but leaves the session
available for subsequent execution. Prior state changes and external side
effects are not rolled back. Execution status and session lifecycle status must
be reported separately so a failed task is not mistaken for a dead interpreter.

### 13.2 Hard failures and internal transport closure

Hard errors, including memory exhaustion or native crashes, need not be
recoverable within a worker. It is acceptable for the session process to die.
The manager must monitor worker exit and the private transport: if the transport
closes before a complete valid execution response is received, it must report
a worker/transport failure to the client rather than wait indefinitely for a
Lua-level exception response. It must also resolve pending session waits.

The session is marked terminated and its in-memory state is lost. Reap a dead
worker; if a worker has lost its transport but remains alive, terminate and reap
it. Perform cleanup without blocking unrelated sessions. A complete response
received before transport closure remains the execution result, but subsequent
closure must still update the session lifecycle status appropriately.

Report exit status, signal, and already captured output where available. An
internal EOF alone does not prove memory exhaustion or any other particular
cause; report unknown causes honestly. Explicit kill and manager-enforced hard
timeout retain their specific outcomes rather than being overwritten by the
expected transport closure during cleanup. Record a terminal outcome once and
resolve affected requests consistently despite exit/EOF/timeout races.

No worker-side diagnostic is guaranteed for a hard failure. Only output already
delivered to the manager can be guaranteed available after process death;
worker-buffered output may be lost. This protection applies to managed workers,
not embedded handlers sharing their host process. Nor does it guarantee survival
of the manager if host-wide memory exhaustion kills it as well.

### 13.3 API and MCP error reporting

Reject invalid arguments, unknown sessions, and unsupported or busy operations
before executing code. Malformed MCP/JSON-RPC requests use protocol error
responses; valid tool calls that fail use MCP tool-error results. The final
schema must distinguish Lua errors, invalid operation/state, worker/transport
failure, hard execution timeout, and explicit termination.

Synchronous execution and `session_wait` return the same terminal error payload.
A wait timeout alone returns pending status, not a failed execution. Once an
async execution call has returned, later failure is reported through retained
session status and `session_wait`, not a second response to the original call.

## 14. Open implementation decisions

The following have not yet been agreed:

- MCP protocol version and dependency strategy.
- Manager launch command, packaging, and optional programmatic module API.
- Session identifiers, tool names, request and response schemas, and reset
  identifier semantics.
- Precise Lua embedding API and its compatibility with `dosbox-y`.
- Result rendering, output limits, and oversized-result behaviour.
- Null sentinel API, exact numeric conversion policy, and typed return-value
  schema, including binary data and non-JSON Lua values.
- Event-loop and process-spawning dependencies, internal worker protocol, and
  per-session request queueing or busy-response policy.
- Execution timeout field, units, bounds, omitted-timeout policy, and ordering
  rules for completion racing with the deadline.
- Wait-timeout omitted-value default and numeric precision; task tool schemas,
  retention and expiry limits, and ordering for kill racing with completion.
- Deployment authentication and authorization for any network transport.
- Acceptance or revision of the proposed policies in section 11, including
  disconnect cleanup, cancellation, platform support, and resource bounds.

These decisions must preserve the independent handler, shared host environment,
full-access trust model, explicit lifecycle handoff, and blocking single-threaded
execution specified above.
