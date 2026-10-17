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
destroy or reinitialize that interpreter when a connection ends or a
close is requested.

MCP framing and transport concerns must remain separable from code evaluation
and lifecycle policy. A custom integration may supply its own transport and
lifecycle handling without depending on the manager.

### 2.3 Direct handler API and explicit disconnect

A directly exposed session handler provides a similar execution interface to
the manager, but operates synchronously on its one existing interpreter. Its
execution tool accepts code and optional JSON arguments, using the same
conversion and terminal result conventions as the manager, without session
metadata. It has no `session_id`, session allocation/listing, async waiting,
or manager-enforced execution deadline. The host interpreter is implicit.

The handler must also expose a `repl_close` MCP tool, requiring no session ID,
to acknowledge closure and end the blocking MCP-serving invocation. This tool is distinct from
the manager's `session_kill`: it does not terminate a process or dispose of the
host interpreter.

On accepting `repl_close`, the handler must:

1. Stop accepting further execution requests for that invocation.
2. Send and flush a successful close acknowledgement before returning,
   if the transport is still writable.
3. End its protocol attachment without closing or shutting down the underlying
   transport. Cleanup belongs to the parent code/custom manager that set it up.
4. Return control to the host with an explicit close-requested reason and
   acknowledgement status, including any transport error that
   prevented completing those steps.

The parent decides what happens after the handler returns; physical disconnection
is not a postcondition of the handler call. Custom parent code may preserve or
close the transport, preserve or reset interpreter state, terminate the host,
or perform another action appropriate to that application.

For the standard manager's worker, the parent wrapper terminates the session
process after the handler returns. Process exit closes its transport descriptors.
The manager observes that exit and marks the session terminated. Custom managers
are not required to adopt this exit policy. The handler itself only acknowledges
the request and returns control; it neither exits the process nor owns cleanup.
The handler itself must not clear globals, reset Lua, or kill the host. No
requests after the close acknowledgement may be executed, including requests
already buffered behind the close command.

Because this handler is blocking and single-threaded, `repl_close` is processed
only when the handler resumes servicing requests. It cannot interrupt an active
Lua chunk or native host call. The manager's worker control protocol need not
expose or forward this direct-handler close tool as a public manager operation.

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

The handler accepts complete Lua chunks, compiled and executed without source
rewriting or expression-detection fallback. Returned values always require an
explicit Lua `return` statement, including for single expressions: use
`return x * 2`, not bare `x * 2`. Chunks without `return` may execute normally
but produce no returned values; captured output is still reported. Compilation
and runtime errors must never trigger a second execution attempt.

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

Multiple return values must preserve their number and order. Each returned value
must be representable in JSON without a custom typed-value encoding. If any
value cannot be represented, return a result-serialization error and discard
the entire return-value payload; do not substitute descriptions, truncate the
result, or return only the serializable subset. Section 13.4 defines this policy.

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
- Unrecoverable handler or transport error.

A syntax or runtime error in submitted Lua code is an execution result, not
automatically an unrecoverable handler error.

Close is an application-level MCP tool operation, not a standard MCP shutdown
method. The direct-handler tool is `repl_close`; manager disposal uses
`session_kill`.

For embedded use, the host may keep the Lua state, reset it, or terminate the
interpreter or application. The handler must convey the reason and relevant
request context; merely returning without a reason is insufficient to distinguish
these policies. A custom host may intentionally treat REPL termination as the
point at which it resets or shuts down.

For standalone sessions, `session_kill` releases manager-owned session resources,
whether the session is idle or executing. No separate `session_close` tool is
required.
There is no reset tool. To obtain fresh state, kill the old session and create
another, explicitly or with a null session ID on execution. A new session gets
a new ID; IDs must not be reused during the manager's lifetime.

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
- An embedded handler may not observe cancellation or disconnect until execution
  returns. The manager can observe them independently of a running worker.
- Managed-request cancellation triggers termination as specified in section 11.3;
  it does not undo side effects or imply instantaneous process exit. Client-side
  timeout without notification does not by itself stop execution.
- An infinite loop or permanently blocked native call may require external host
  intervention. Full system access does not make forced interruption safe.
- Clients must not automatically retry a timed-out state-changing execution on
  the assumption that it did not run.

### 7.1 Manager-enforced execution timeouts

Managed execution requests may specify an execution timeout. The manager owns
worker process creation, supervision, and termination, and enforces the timeout
using its event loop independently of the worker's Lua execution.

The timeout starts when execution is dispatched to the worker. Busy sessions
reject additional execution requests rather than queueing them. If execution has not completed before
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
worker termination. The optional `execution_timeout_ms` is a positive integer
in milliseconds. When omitted, there is no manager-imposed hard execution
deadline. Permitted upper bounds remain a schema decision.

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

Omitted `wait_timeout_ms` defaults to 600000 milliseconds (10 minutes) for both
execution and wait tools. This is a wait deadline, not a hard execution deadline.
Explicit null and zero retain their documented meanings. Whether fractional
milliseconds are accepted remains a schema decision. Negative, non-finite, and otherwise invalid
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
or a wildcard. Wait and kill require a concrete session ID and must not
allocate workers as a side effect. The behaviour of an omitted `session_id`
remains a schema decision; explicit null must be supported.

JSON-RPC request IDs correlate protocol requests and responses, not executions.
A response identifies the session and whether its execution is pending or
terminal. If the wait expires, the manager must return control without cancelling,
restarting, or resubmitting the execution. The client can subsequently poll that
same session for status and retrieve its terminal result, including output or errors.
The final result must remain retrievable even if completion races with returning
the pending response, until returned to a caller or replaced by the next execution.
Status and result retrieval must not execute the code again.

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
result immediately and consumes that retained result. Retain terminal results
until returned by either `session_execute` or `session_wait`, or replaced by
the next accepted execution, without time-based result expiry. Returning a
terminal result always consumes it, including errors. A response containing
only pending status consumes nothing.

Synchronous execution is conceptually asynchronous dispatch followed by a wait.
The initial execution call's wait and any later explicit wait use the same
single-consumer result mechanism. This applies both to indefinite synchronous
execution and to execution completing within a finite wait deadline. Once the
terminal result is returned, it is gone; a later wait cannot retrieve it again.
Unknown sessions, consumed results, and sessions without an execution produce
explicit, distinguishable errors. Keep lightweight status after consumption.
Rejected executions must not discard the preceding result. These rules also
apply to failed results and results from terminated sessions.

Consume when a terminal execution or wait response is committed for transmission;
delivery cannot be guaranteed after disconnect. If multiple waits are outstanding,
including the initial execution call's wait, one
receives and consumes the payload; the others receive a result-unavailable error
with terminal status. An existing pending waiter must not receive a newer
execution's result if the session is reused.

Each session exposes at most one current execution and its result. Starting a
new execution replaces the previous retained result. Historical
executions cannot be addressed through this API. A pending wait is internally
bound to the execution current when the wait was accepted, so a later execution
cannot substitute a different result for that waiter. Internal generation
identifiers may be used for this purpose but are not client-facing task IDs.

The manager remains responsive while a wait is pending, including to a kill
request for the same task. A task ending through success, failure, hard timeout,
or explicit kill resolves its pending waits according to the single-consumer
rules above. This tool also provides polling and result retrieval; separate tools
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
cannot subsequently kill another worker or execution.

A successful kill response must not claim termination before the manager has
confirmed worker exit. Requests waiting for the task must resolve consistently
with its recorded terminal outcome. Failure to terminate a worker must be
reported, not presented as successful cleanup. Other sessions remain available.

Kill has only a synchronous interface: no wait-timeout parameter or asynchronous
kill handle. Its request remains pending until termination and cleanup are
confirmed or a termination error is reported. The manager continues servicing
other sessions while this request waits. Internally the target is terminating
and rejects new execution; this is not a client-visible asynchronous kill mode.

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
manager returns an empty list. Keep terminated entries with unconsumed results
available for retrieval. After consumption, metadata may be removed according
to a documented policy; terminated entries must not appear usable.
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
   owns; a fresh session starts with fresh state and a new ID.
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
    timeout, and consumes the terminal result without re-execution. A subsequent
    wait reports result unavailable; a pending response does not consume a result.
    A terminal result returned directly by `session_execute` is likewise consumed,
    with exactly the same semantics as asynchronous execution followed by wait.
17. `session_kill(session_id)` disposes of newly allocated, idle, or running
    sessions; pending execution waits resolve as killed. Repeating the kill
    has no further side effects. Accepted kill cleanup never
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
22. A direct handler exposes synchronous execution without session identifiers
    and a `repl_close` tool. Close acknowledges before returning where possible,
    returns a structured lifecycle reason, and leaves transport handles and Lua
    state intact. The standard worker wrapper then exits the process; custom
    parent code chooses its own continuation and cleanup policy.

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

The handler communicates through a dedicated pair of input/output file
descriptors, separate from the application's standard input, output, and error.
A host-supplied bidirectional socket may back these logical read/write endpoints.
The handler must not require opening a listener, creating a connection, or
launching the manager. The host supplies the dedicated channel through the I/O
adapter; the standalone manager arranges descriptors during worker startup.

Because standard Lua has no portable API for arbitrary sockets and file
descriptors, the pure-Lua handler accepts a host-supplied I/O adapter wrapping
those handles. The adapter provides read and write operations.
Integration with host-specific handles
belongs in the adapter, not in the REPL evaluator.

The adapter contract must define partial reads and writes, end-of-input, and I/O
errors. It must work with byte streams without assuming that one read equals
one complete MCP message. The parent code retains ownership of all supplied
handles. The handler must never close or shut them down, including on
`repl_close`, EOF, or error. It returns the reason and transport status so the
parent can perform cleanup. Interpreter ownership remains independent of
transport ownership.

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
transport. A new session requires new allocation. The manager
must detect worker termination, report affected request failures, and remain
available for other sessions. Process separation protects against ordinary
worker exit but is not a sandbox against full-access code deliberately affecting
the manager or other processes.

Streamable HTTP is a possible future standard transport for independently
running or remote deployments, but is not required initially. Unix-domain
sockets and raw TCP remain possible custom integrations through the supplied
I/O adapter; the initial manager need not listen on either. Legacy HTTP+SSE
transport is not required.

### 10.3 Worker startup and standard streams

Session creation is successful only after the manager receives a valid worker
ready handshake confirming that the handler and its dedicated control channel
are usable. Enforce a configurable, finite `startup_timeout_ms` using a monotonic
clock, starting when allocation begins. The default and permitted range must
be documented. This deadline is separate from execution and wait deadlines.

If startup fails or readiness is not established before the deadline, abort
allocation, terminate and reap any started worker, close allocated descriptors,
and return a `session_creation_error` with a reason such as `startup_timeout`,
`spawn_failed`, `stdio_setup_failed`, or `handshake_failed`. No user code may run
before readiness. Apply the same checks to implicit allocation by execution.
The manager must remain responsive during startup and cleanup, and late ready
messages must not revive an aborted allocation.

`session_create` accepts optional `stdin_path`, `stdout_path`, and `stderr_path`
parameters. Standard input reads from the supplied file; standard output and
error write to new files created when the session is initialized. Use exclusive
creation: an existing output path is an error rather than being appended to or
truncated. Keep these files open across tasks. Each omitted stream defaults to
`/dev/null`, opened as a device rather than created exclusively. Standard input
reads the supplied existing file. If stdout and stderr specify the same path,
create it once and share the opened destination. Path resolution and handling of
files created before a startup failure remain to be finalized.
These streams are separate from captured Lua `print` output
included in execution results; any mirroring of captured output must be explicit.
For implicit creation, the execution API must expose equivalent creation options
or document that it uses defaults; that schema choice remains open.

During worker setup, establish the dedicated control descriptors and redirect
FDs 0, 1, and 2 without overwriting control endpoints. Close unused pipe ends and
unrelated inherited descriptors. Arrange descriptor inheritance so child
programs do not unintentionally retain the control channel and prevent EOF
detection. The manager must monitor worker exit independently of EOF.

Worker standard output must never inherit the manager's MCP protocol stdout.
Ordinary `io.write`, native-library output, and subprocess standard output go
to the configured file or `/dev/null`, not into protocol framing. Failure to
open a configured stream is a creation error rather than silent fallback.
Automatic stream redirection is a managed-worker feature; an embedded host
retains control of its own standard streams.

## 11. API policies and remaining proposals

Policies in this section are requirements unless explicitly marked as proposals.
Dependency selection still requires a final decision.

### 11.1 Public tool surface and code entry

Manager tools include `session_create`, `session_list`, and `session_execute`.
Required execution-control and disposal tools are
`session_wait` and `session_kill`, as specified in sections 7.3 and 7.4. All
session-scoped tools use `session_id`, not a separate task identifier.
The single execution tool implements all waiting modes in section 7.2 rather
than separate synchronous and asynchronous tools. A directly embedded handler exposes
execution and only those lifecycle operations the host supports; it does not
pretend to create or manage independent host interpreters.

Execution accepts complete Lua chunks with explicit `return` for results,
as specified in section 4. For example, `x = 7` sets a persistent global and
a later `return x * 2` returns its computed value. No automatic return is added.
Chunk-local variables follow ordinary Lua scope and do not become globals.

### 11.2 Busy sessions and lifecycle operations

Reject another execution with a `session_busy` tool error while that
session is running. There is no execution request queue. Rejection must not
execute any code, alter the active execution, or replace its result. Other sessions
remain available. Kill must remain actionable while a worker is busy; it
terminates the active worker and resolves its pending execution as killed.

### 11.3 Timeout and cancellation policy

Accept an optional positive integer `execution_timeout_ms` on managed execution,
separate from `wait_timeout_ms`. When
omitted, execution has no manager-imposed deadline; client deadlines still apply.
Use a monotonic clock and define completion as the manager receiving a complete,
valid worker response before the deadline. Disarm the request's timer on
completion so it cannot later kill an idle or replacement worker.

MCP cancellation of an in-progress `session_execute` or `session_wait` request
kills its associated managed session, with the same process termination and
state-loss semantics as `session_kill`. This also resolves other pending waits
for that execution as terminated. Cancelling in-progress creation, including
implicit creation, aborts allocation and cleans up any started worker without
dispatching user code. Cancellation of an already accepted kill must not stop
cleanup. Read-only listing cancellation has no session-termination side effect.

Resolve cancellation by the JSON-RPC request ID, using the session/worker bound
to that outstanding request. Unknown, already completed, or already answered
request IDs must not kill any session. In particular, cancelling an async
execution call after its pending response has been sent cannot kill its worker;
the client must use `session_kill` instead. Late cancellation must never target
a later execution or newly allocated worker.

Standard MCP `notifications/cancelled` is a notification, with no response of
its own. Follow MCP guidance on suppressing responses to cancelled requests;
clients may ignore any late response. The terminated state and reason remain
observable through session listing and retained execution results. Tool
descriptions must explicitly state that request cancellation destroys session
state, including cancellation sent automatically by a client on its deadline.

This is distinct from an ordinary `wait_timeout_ms` expiry, which returns a
pending response and leaves execution running. A client-side timeout without
an actual cancellation notification does not itself trigger worker termination.
Direct embedded handlers cannot service cancellation while running code and
must never implement this policy by killing their host.

### 11.4 Connection ownership and shutdown

Managed sessions are owned by the manager's stdio connection. Client disconnect,
including end-of-input or unrecoverable client-output failure, and manager
shutdown terminate and reap all owned workers, including starting, idle, and
running sessions. Stop accepting new work and abort pending allocations when
disconnect is detected. Reconnecting does not
restore their state. No detached sessions, persistence to disk, or automatic
recovery of interpreter state is required initially.

Embedded disconnect handling remains host-owned as specified above.

### 11.5 Results, errors, and resource bounds

Execution results include captured output, an ordered list of JSON-compatible
return values, and structured error information on failure. Nonrepresentable
results produce an error and the entire return-value payload is discarded;
custom typed encodings and descriptive object inspection are not supported.
Section 13.4 governs serialization and table-shape rules.

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

The initial manager platform is POSIX. Windows support is outside the initial
scope. Any platform-specific implementation extensions must be identified;
Linux-only APIs must not silently become baseline requirements. Selection of an
OS/event-loop dependency, potentially with native bindings, remains open. Such
a dependency must not become required by the embeddable handler. Robust
descendant-process cleanup remains a separate explicit decision.

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

Empty arrays and objects both become empty Lua tables, which return as JSON
objects; preserving an empty input array's original shape is not implied.
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

### 13.4 Nonrepresentable return values

If a return value cannot be represented faithfully by the supported JSON mapping,
report `result_serialization_error` and discard all returned values for that
execution. This includes functions, userdata, threads, cyclic tables, non-finite
numbers, invalid UTF-8/binary strings, and tables whose keys or shape cannot be
represented by the chosen JSON table mapping. Do not stringify unsupported
objects or invent tagged encodings to make the result appear successful.

Represent ordinary Lua `nil` returns as JSON null entries in the outer return
array, preserving the explicit return count: zero returns is `[]`, while one
nil return is `[null]`. The documented JSON null sentinel also maps to JSON
null. Nonempty tables with exactly consecutive integer keys from 1 to N become
JSON arrays. String-only keyed tables become objects; empty tables become
objects. Reject mixed key types, holes, and unsupported key types. Inspect raw
entries without invoking `__pairs`, `__index`, or conversion metamethods.
Numeric precision rules remain to be finalized; reject values outside that
contract rather than silently losing data. Detect cycles and enforce serialization bounds.
Exceeding a result bound is an error, not successful result truncation.

Serialization failure occurs after execution and does not roll back side
effects or terminate an otherwise healthy session. Preserve captured output
and error diagnostics, but expose no partial return-value payload. Apply the
same rule to direct execution and results obtained via `session_wait`.

### 13.5 Diagnostic encoding and failure codes

Error messages, tracebacks, and captured output must remain valid JSON when
Lua produces invalid UTF-8. Escape invalid bytes with a documented printable
convention instead of letting diagnostic encoding mask the original failure.
Flag affected diagnostics/output with `data_preserved: false` and a readable
notice that the original data was not fully preserved. Also flag truncation
caused by diagnostic/output limits. Ordinary JSON escaping alone does not imply
data loss. Returned values still follow the strict rejection policy above.

Tool failures must expose stable machine-readable failure codes, not require
clients to classify prose. Distinguish at least invalid arguments, unknown
session, busy session, terminated session, no execution, result unavailable,
session creation failure, Lua syntax error, Lua runtime error, result
serialization error, hard execution timeout, explicit kill, request
cancellation, worker exit, and control-transport failure. Preserve creation
failure subreasons such as startup timeout or stream setup failure.

Each execution error must identify its stage and whether user code did not
start, started with potentially partial effects, completed before result
conversion failed, or has an unknown outcome. Report session usability
separately. A serialization failure must explicitly say execution completed
and its effects remain; it must not encourage automatic re-execution. Exact
code strings and schema remain to be finalized consistently across manager
and direct-handler tools.

## 14. Open implementation decisions

The following have not yet been agreed:

- MCP protocol version and dependency strategy.
- Manager launch command, packaging, and optional programmatic module API.
- Session identifiers and complete tool request and response schemas.
- Precise Lua embedding API and its compatibility with `dosbox-y`.
- Result rendering, output limits, and oversized-result behaviour.
- Null sentinel API, exact numeric conversion policy, and complete JSON return-value schema.
- Event-loop and process-spawning dependencies and internal worker protocol.
- Execution timeout upper bounds and ordering
  rules for completion racing with the deadline.
- Wait-timeout numeric precision; task tool schemas, consumed-session metadata
  retention, and ordering for kill racing with completion.
- Startup deadline default/bounds, standard-stream path resolution and failed
  startup file cleanup, and creation options for implicit session allocation.
- Deployment authentication and authorization for any network transport.
- Resource-bound defaults.

These decisions must preserve the independent handler, shared host environment,
full-access trust model, explicit lifecycle handoff, and blocking single-threaded
execution specified above.
