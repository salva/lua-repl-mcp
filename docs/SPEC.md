# Lua REPL over MCP — Specification

Status: initial functional specification.

## 1. Objective

Provide a Lua module implementing a persistent REPL accessible through the Model
Context Protocol (MCP). An MCP client, including an LLM agent, submits Lua code,
the code executes synchronously, and the client receives returned values or errors.

The project must support both standalone sessions and integration into existing
applications embedding Lua. Host-specific adapters must be validated against
their application's embedding API without coupling the core to a particular host.

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
already buffered behind the close command. Preserve complete trailing messages
for the parent in arrival order without executing them. Preserve any partially
read trailing frame as well, so the parent can resume without losing bytes.

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
but produce no returned values. Compilation
and runtime errors must never trigger a second execution attempt.

Globals and globally reachable functions and objects persist between requests.
Ordinary chunk-local variables follow Lua's normal scoping rules; the REPL does
not promise to preserve lexical locals between separately compiled chunks.

Execution results must distinguish:

- Successful execution, including zero or more returned values.
- Syntax or compilation errors.
- Runtime errors, with diagnostic context where available.

Ordinary Lua errors must not end an otherwise usable session. Errors do not roll
back changes already made to Lua state or external resources.

Multiple return values must preserve their number and order. Each returned value
must be representable in JSON without a custom typed-value encoding. If any
value cannot be represented, return a result-serialization error and discard
the entire return-value payload; do not substitute descriptions, truncate the
result, or return only the serializable subset. Section 13.4 defines this policy.

The handler and manager must not capture execution output or replace `print`,
`io.write`, or host output functions. Output goes to the host's normal streams
or the managed worker's configured files/default `/dev/null`. Clients needing
capture must implement it in submitted Lua and return the captured data explicitly.
There is no automatic output field in execution results, including failures.

Dedicated control descriptors keep ordinary standard-stream output separate
from protocol framing. Full-access code can still deliberately interfere with
control descriptors; this is not a sandbox guarantee.

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
deadline. Bounds are defined in section 14.

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
Explicit null and zero retain their documented meanings. Milliseconds must be
integers. Negative, non-finite, and otherwise invalid
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
allocate workers as a side effect. Omitted `session_id` defaults to null.

JSON-RPC request IDs correlate protocol requests and responses, not executions.
A response identifies the session and whether its execution is pending or
terminal. If the wait expires, the manager must return control without cancelling,
restarting, or resubmitting the execution. The client can subsequently poll that
same session for status and retrieve its terminal values or errors.
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
usable after termination. Section 14 defines statuses and schemas. Closed
sessions are removed immediately; live-session results follow section 7.3.

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
explicit, distinguishable errors. Keep lightweight status after consumption
only while the session remains alive.
Rejected executions must not discard the preceding result. These rules also
apply to failed results while the session remains alive. On termination,
resolve existing waiters, then discard all session metadata and retained data.
Later calls receive `unknown_session`, not a historical error payload.

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
to be killed. Remove the session on termination or the bounded best-effort
cleanup fallback specified in section 14. Subsequent calls,
including repeated kill, receive `unknown_session` without side effects.

Because selection is by session, a delayed kill received after a new execution
starts targets that new execution. Clients must coordinate execution and kill
requests accordingly; the API cannot express "kill only an older run". Once a
kill is accepted, cleanup must be internally bound to the selected worker so it
cannot subsequently kill another worker or execution.

A kill response reports successful disposal of the managed session after bounded
best-effort termination, even if the OS has not confirmed worker exit. Include
`process_exit_confirmed` so success does not falsely assert that the process is
dead. Requests waiting for the execution resolve consistently with its recorded
outcome. Other sessions remain available.

Kill has only a synchronous interface: no wait-timeout parameter or asynchronous
kill handle. Its request remains pending until cleanup completes or its bounded
best-effort fallback is reached. The manager continues servicing
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
distinguish starting, idle, running, and terminating sessions,
and indicate whether a terminal execution result is still available through
`session_wait`. Listing must not create sessions, execute code, or consume results.

The manager must answer listing requests while workers are executing. An empty
manager returns an empty list. Terminated sessions and their results are removed
immediately. Listing has no pagination initially and is bounded by session limits.

## 8. Initial acceptance criteria

1. A client defines a global and a function, then uses both in a later request.
2. A client receives returned values, including multiple values with intervening
   `nil` values. Output is not captured automatically; client Lua may explicitly
   implement capture and return its data.
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
10. MCP protocol messages remain separate from session standard streams.
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
    returns unknown-session without further side effects. Accepted kill cleanup never
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
21. Ordinary Lua errors return diagnostics without
    terminating the session. Worker exit or premature internal transport closure
    instead resolves pending executions and waits as failures and marks the
    session terminated; unrelated sessions remain usable.
22. A direct handler exposes synchronous execution without session identifiers
    and a `repl_close` tool. Close acknowledges before returning where possible,
    returns a structured lifecycle reason, and leaves transport handles and Lua
    state intact. The standard worker wrapper then exits the process; custom
    parent code chooses its own continuation and cleanup policy.
23. If one read contains `repl_close` and trailing complete or partial frames,
    the handler returns those frames to the parent in order without executing
    them or closing the transport.
24. Out-of-range integral numbers are rejected consistently for JSON integer,
    decimal, and exponent spellings and Lua integer/float results; conversion
    does not silently round them into the accepted range.

## 9. Lua version support

Target **PUC-Rio Lua 5.4 and newer (5.4+)** for standalone and embedded use.
Lua 5.4 is the minimum supported version and the initial integration test target.

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

`session_create` accepts optional `cwd`, `stdin_path`, `stdout_path`, and `stderr_path`
parameters. Standard input reads from the supplied file; standard output and
error write to new files created when the session is initialized. Use exclusive
creation: an existing output path is an error rather than being appended to or
truncated. Keep these files open across tasks. Each omitted stream defaults to
`/dev/null`, opened as a device rather than created exclusively. Standard input
reads the supplied existing file. If stdout and stderr specify the same path,
create it once and share the opened destination. Resolve stream paths against
the chosen session directory; retain files created before startup failure.
These streams include ordinary Lua `print` output. Neither the manager nor
handler captures or mirrors that output into execution results.
Implicit creation exposes equivalent settings through `create_options`.

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

## 11. API policies

Policies in this section are requirements. Section 14 specifies dependencies
and concrete API defaults.

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
clients may ignore any late response. The terminated state and reason are
delivered to other already-pending waits; no closed-session history is kept. Tool
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

Execution results include an ordered list of JSON-compatible
return values, and structured error information on failure. Nonrepresentable
results produce an error and the entire return-value payload is discarded;
custom typed encodings and descriptive object inspection are not supported.
Section 13.4 governs serialization and table-shape rules.

Define configurable limits for input messages, return-value depth and size,
diagnostics, and managed session count. Truncate oversized diagnostic text with
an explicit indicator. Worker standard streams go to files/devices, not capture
pipes. Control-channel processing must use bounded buffers and avoid deadlock.
Distinguish transport corruption and worker crashes from Lua runtime errors.

### 11.6 Platform and dependency boundary

The pure-Lua handler and host-supplied I/O adapter do not imply the standalone
manager can use only standard Lua libraries: standard Lua does not provide the
required portable process supervision and nonblocking descriptor APIs.

The initial manager platform is POSIX. Windows support is outside the initial
scope. Any platform-specific implementation extensions must be identified;
Linux-only APIs must not silently become baseline requirements. The manager uses
luaposix; this dependency must not become required by the embeddable handler.
Descendant-process termination is not guaranteed initially.

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
can identify nulls via `require('lua_repl_mcp').null`, without overwriting host globals.

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
available. Lua may throw values
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

Report exit status and signal where available. An
internal EOF alone does not prove memory exhaustion or any other particular
cause; report unknown causes honestly. Explicit kill and manager-enforced hard
timeout retain their specific outcomes rather than being overwritten by the
expected transport closure during cleanup. Record a terminal outcome once and
resolve affected requests consistently despite exit/EOF/timeout races.

No worker-side diagnostic is guaranteed for a hard failure. Output is not
captured by the manager, and process-buffered file output may be lost on death.
This protection applies to managed workers,
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
async execution call has returned, ordinary Lua failure is retrieved through
`session_wait`, not a second response to the original call. Fatal termination
removes the session; if nobody is waiting, subsequent calls receive
`unknown_session` without historical failure details.

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
Numeric precision rules are specified in section 14; reject values outside that
contract rather than silently losing data. Detect cycles and enforce serialization bounds.
Exceeding a result bound is an error, not successful result truncation.

Serialization failure occurs after execution and does not roll back side
effects or terminate an otherwise healthy session. Return error diagnostics,
but expose no partial return-value payload. Apply the
same rule to direct execution and results obtained via `session_wait`.

### 13.5 Diagnostic encoding and failure codes

Error messages and tracebacks must remain valid JSON when
Lua produces invalid UTF-8. Escape invalid bytes with a documented printable
convention instead of letting diagnostic encoding mask the original failure.
Flag affected diagnostics with `data_preserved: false` and a readable
notice that the original data was not fully preserved. Also flag truncation
caused by diagnostic limits. Ordinary JSON escaping alone does not imply
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
code strings and schemas are defined consistently for manager and direct-handler
tools in section 14.

## 14. Final API contract and defaults

This section fixes the API contract. Machine-readable definitions are in
`schemas/api.json`; complete wire examples are in `MCP_EXAMPLES.md`.

### 14.1 Protocol and dependencies

Target MCP `2025-11-25` over JSON-RPC 2.0. Implement initialization/version
negotiation, initialized notification, ping, tools/list, tools/call, and request
cancellation. Advertise tools only; do not claim standard MCP Tasks support.
Initialization must precede tool use. Malformed protocol requests use JSON-RPC
errors; valid tool calls that fail use tool results with `isError: true`.

Publish input/output JSON Schemas. Tool results carry an object in
`structuredContent` and the same JSON in a text content block for compatibility.
Descriptions must explain state persistence, explicit return, single-consumer
results, both timeout meanings, and cancellation killing the session. Execution
is neither read-only nor idempotent. Direct-handler discovery advertises close
as a real MCP tool, not merely an internal function.

In `schemas/api.json`, `$defs/<tool_name>` is the input schema and
`$defs/<tool_name>_output` is its structured-result schema. Resolve/integrate
references before publishing; every advertised tool schema must be independently
usable, with an explicit root `type: object`, including reference wrappers.
Schema defaults are descriptive: the implementation must apply them.
JSON Schema does not enforce numeric lexical precision, UTF-8 correctness,
session state, equality of an echoed ID to a prior request, or exclusive file
creation; runtime checks enforce those rules. Run `python3 docs/check_contracts.py`
to check schema expansion, official MCP discovery compatibility, examples, and
negative regressions (setup and offline usage are in `MCP_EXAMPLES.md`).
Set `isError: true` exactly when a tool payload contains `error`; normal pending,
completed, closing, creation, listing, and best-effort kill results use false.

Package Lua modules under `lua_repl_mcp` with a LuaRocks package and executable
`lua-repl-mcp` launching the stdio manager. Use luaposix for POSIX process,
descriptor, signal, and polling facilities; verify required bindings on Lua 5.4
and pin a compatible release during implementation. Use a pure-Lua JSON codec
with explicit null and strict string/number validation. The handler must not
import manager/native dependencies. Codec selection must pass the data-contract
tests; silently lossy decoding is not acceptable.

### 14.2 Tools and creation options

Reject unknown fields. Paths and code are strings. IDs are opaque strings
generated by the manager and never reused within its lifetime.

| Tool | Arguments |
| --- | --- |
| `session_create` | Optional `cwd`, `stdin_path`, `stdout_path`, `stderr_path` |
| `session_execute` | Required `code`; optional `session_id` (null), `args` ([]), `wait_timeout_ms` (600000), `execution_timeout_ms` (null), `create_options` |
| `session_wait` | Required non-null `session_id`; optional `wait_timeout_ms` (600000) |
| `session_kill` | Required non-null `session_id` |
| `session_list` | No arguments |
| Direct handler `repl_execute` | Required `code`; optional `args` ([]) |
| Direct handler `repl_close` | No arguments |

Parenthesized values are defaults. `create_options` accepts the same fields as
`session_create` and is permitted only with a null session ID. Sessions inherit
the manager's environment. With omitted `cwd`, they inherit its working directory.
Resolve relative `cwd` against that directory, and relative stream paths against
the chosen session directory. An unusable directory is a creation error; there
is no silent fallback. List entries report the effective initial directory.

Output files use exclusive creation with mode 0600 subject to umask; existing
paths fail rather than overwrite. Shared stdout/stderr paths are opened once.
Standard input reads an existing file; omitted streams use `/dev/null`.
Keep files created before startup failure and identify them in the error rather
than deleting them. Perform potentially blocking file setup in the supervised
worker before its readiness handshake so the manager's startup timer can abort
a blocked open. Setup must not block the manager event loop.

Timeouts use integer milliseconds up to 2147483647. Wait accepts null, zero,
or positive values; hard execution timeout accepts null or positive values.
Null/omitted hard timeout means no deadline. Invalid arguments fail before
allocation. Completion requires a complete valid worker response received
before the monotonic deadline; late responses cannot reverse a timeout.

### 14.3 Payloads and errors

Execution/wait responses use `status: running|completed|failed` to describe
execution, not success of retrieving its result. An operation error may retain
`status: completed` (result already consumed) or `status: running` (session busy).
When no execution can be identified, omit status. MCP `isError` reports the
tool operation's success independently. Manager execution/wait responses for a known session
also include `session_id`, `session_status`, and `session_usable`; direct-handler
responses omit session metadata. Terminal success includes `values` (ordered
JSON array). Errors omit values and include `error`. Error-free completed
responses require values; pending responses include neither values nor error.
No output-capture field exists. Unknown-session errors echo the supplied ID but
omit both session status and execution status and set session_usable false.
Validation/creation errors
before a session exists omit all session metadata.

An error contains `code`, `message`, `stage`, and `execution_state`.
Stages are `validation`, `creation`, `execution`, `serialization`, `transport`,
and `termination`. Execution states are `not_started`, `started`, `completed`,
and `unknown`. Optional fields are `traceback`, `path` identifying an offending
value, `reason`, and `data_preserved`. Altered diagnostics explicitly set the
last field false and include the agreed readable notice. `path` uses RFC 6901
JSON Pointer rooted at tool arguments for input errors and at a conceptual
`{"values": [...]}` object for result errors. Array indices in pointers are
zero-based even though Lua indices are one-based. `execution_state` refers to
the submitted code for execute and to the selected execution for wait. For busy
execute it is not_started, even though status describes the existing running
execution. For non-execution lifecycle requests use unknown unless a specific
execution outcome is being reported.

Additional optional error fields are `exit_code` (nonnegative integer),
`signal` (positive integer), `created_files` (reported created paths),
`created_files_complete` (boolean), `truncated` (boolean),
`invalid_bytes_escaped` (boolean), and `process_exit_confirmed` (boolean).
The last field also appears on execution responses affected by process cleanup.
Top-level `notice` must be a nonempty string explaining unconfirmed exit whenever
`process_exit_confirmed` is false at the top level or inside `error`. Only include
OS exit information actually observed; never infer a signal from EOF alone.
Diagnostic bounds cover the combined message and traceback after invalid-byte
escaping; reserve space for the truncation notice and flags.

Codes are `invalid_arguments`, `unknown_session`, `session_busy`,
`session_terminating`, `no_execution`, `result_unavailable`, `session_limit`,
`session_creation_error`, `lua_syntax_error`, `lua_runtime_error`,
`result_serialization_error`, `execution_timeout`, `session_killed`,
`request_cancelled`, `worker_exited`, `transport_error`,
and `limit_exceeded`. Creation reasons are `startup_timeout`, `spawn_failed`,
`cwd_setup_failed`, `stdio_setup_failed`, or `handshake_failed`.

Creation returns session ID and idle status. Kill returns session ID,
`status: killed`, `session_usable: false`, and `process_exit_confirmed` after
bounded best-effort cleanup. If exit is unconfirmed, also return a notice that
the process may remain alive although its managed session has been removed.
This is a successful tool result, not a termination error. List returns
`sessions` entries with ID, session status, execution status
(`none|running|completed|failed`), `result_available`, and initial `cwd`.
Close returns `status: closing`, acknowledging return to parent code rather
than physical transport closure. Results already returned are never available
for another retrieval; listing availability refers to retained data only.

### 14.4 Lifetime and operational limits

Live session states are `starting`, `idle`, `running`, and `terminating`.
Once termination is confirmed or bounded best-effort cleanup finishes, remove
all session metadata and results immediately;
no tombstones are kept. Already-pending requests receive the termination
outcome, but later requests receive `unknown_session`. A terminal response
already being delivered may report `session_status: terminated`; it does not
imply any retained session. Async fatal failures with no waiting caller have
no historical payload available afterward.

Configurable defaults:

| Setting | Default |
| --- | --- |
| Startup deadline | 30 seconds |
| Wait deadline | 10 minutes |
| Hard execution deadline | None |
| Concurrent sessions, including starting/terminating | 64 |
| Input JSON message | 16 MiB |
| Serialized return values | 16 MiB |
| Diagnostic text per error | 64 KiB |
| JSON/table nesting | 128 levels |
| Outstanding ordinary client requests | 256 |
| Reserved control requests | 32 |
| Complete worker frame | 64 MiB |
| Complete encoded MCP response | 128 MiB |
| Buffered client output | 256 MiB |

Validate operator-configured bounds. Do not impose worker CPU or memory quotas
by default. Diagnostic truncation is flagged; oversized returned values
fail serialization. Keep draining workers with bounded buffers. Apply client
backpressure; if the output buffer cannot stay bounded, disconnect and clean
up sessions. Reject oversized frames without allocating their full length.
Service timers/control operations fairly even under sustained traffic.

MiB means 1048576 bytes. Input limits count UTF-8 JSON frame bytes excluding
the newline. The return-value limit counts the encoded JSON `values` array,
not raw Lua string bytes. The complete response limit includes its JSON-RPC
envelope, structuredContent, compatibility text, and all escaping. Encoder
budget checks must precede committing/consuming a result. A frame exceeding
the response bound becomes a small `limit_exceeded` error without emitting a
partial frame; if value serialization itself exceeds its bound, use
`result_serialization_error`. Internal frames and public requests have separate
limits; do not reject a legal result using the smaller input-frame limit.
Validate configured limits together and reject configurations where one legal
maximum result cannot fit in a complete response and client output budget.

Apply the same checks to defaults and explicit overrides; no default-only
exception or unresolved-fit flag is permitted. Use checked arithmetic and
these conservative minimum capacities, where I is the input-frame limit, V
the encoded-values limit, D the diagnostic-text limit, and H = 1 MiB of fixed
envelope/generated-metadata headroom:

```
B = I + V + 6*D + H
worker_frame_bytes >= B
complete_response_bytes >= I + 3*B + H
client_output_bytes >= complete_response_bytes + 1
```

I in the public-response bound reserves space for a maximum legal encoded
request ID. The factor 3 covers structured content plus its JSON-escaped text
copy; 6*D conservatively covers JSON escaping of diagnostic text. Adding input
and values together deliberately overestimates mutually exclusive payload
cases and leaves room for input-derived error paths and creation metadata.
The output bound includes the newline. Retain exact encoded-size checks and
bounded metadata production; these admission floors do not authorize unbounded
generated fields or replace end-to-end worst-case encoding tests.

At defaults, B is 33.375 MiB and the conservative public-response floor is
117.125 MiB, both below the new 64/128 MiB capacities. The 256 MiB output
buffer holds one maximum permitted public frame with substantial remaining
headroom. Keep the 16 MiB input/value allowances; do not restrict legal IDs or
silently reduce values to make a response fit. Oversized or mutually incompatible
custom limits fail configuration before workers are created. This replaces the
former 20/64/128 MiB worker/response/output defaults and resolves the documented
U7 legal-max request-ID/result conflict without weakening its acceptance test.

Ordinary requests cannot occupy reserved control slots. Kill, list, and ping
may use those slots; cancellation notifications are parsed and handled without
occupying a request slot. At least 8 control slots are reserved for kill alone.
Reject excess ordinary calls with `limit_exceeded` without dispatching them.
Read input fairly even at admission capacity; do not stop reading cancellation
or kill behind a backlog of waiting calls. Control floods remain bounded.

Kill is synchronous to the caller but never blocks the manager event loop.
Use progressive termination: send SIGTERM immediately and repeat every 1 second
for up to 10 seconds; if exit is still unconfirmed, send SIGKILL and repeat every
1 second for the remaining 20 seconds. Stop signalling as soon as child exit is
confirmed. Timers use monotonic elapsed time; delayed event-loop turns must not
extend the 30-second total bound or cause catch-up signal bursts. Signal delivery
success alone does not confirm exit. Retain race-safe child identity throughout;
never retry against a reused PID. Repeated cleanup requests do not restart phases
or deadlines. If exit is not confirmed within 30 seconds, abandon further
termination attempts, close manager-owned transport descriptors, discard the session and
its data, and return successful kill with `process_exit_confirmed: false`.
The worker may exceptionally remain alive outside session management; this must
not retain the client call, session slot, or application-level supervision
indefinitely. Keep only minimal OS child-reaping bookkeeping if needed to avoid
a zombie should it later exit; do not expose that as a retained session.

Apply the same bounded best-effort disposal to timeout, cancellation, failed
startup, transport-failure cleanup, and manager disconnect/shutdown. Preserve
the original failure reason for those operations rather than replacing it with
a cleanup error. An execution still active when killed is reported killed even
if its detached process may continue producing external side effects; include
the unconfirmed-exit notice in affected terminal replies. Never rewrite an
already recorded completed execution as killed. Unknown-session kill requests
remain errors. Descendant-process termination is not guaranteed initially.

### 14.5 Data and embedding

Expose null through `require('lua_repl_mcp').null`, without injecting globals.
Hosts may preload this pure-Lua module. Every mathematically integral numeric
value uses the exact interoperable range -(2^53-1) through 2^53-1, regardless of
JSON spelling or Lua integer/float subtype. Reject larger integral values rather
than round them. For example, `9007199254740993.0`, `9.007199254740993e15`,
and Lua float `1e20` are rejected. Inspect JSON decimal/exponent tokens before
binary conversion so rounding cannot conceal an out-of-range integral value.
Nonintegral values use finite IEEE-754 binary64 semantics with ordinary decimal
rounding; reject overflow, non-finite results, and conversion to an integral
value outside the safe range. Apply the same range test to Lua float results.
Escape invalid diagnostic bytes as literal `\\xHH`, with the loss flag.

`require('lua_repl_mcp.handler').serve(io_adapter, options)` is the blocking
embedding entry point. The adapter provides `read(max_bytes)` (bytes, EOF, or
error), `write(bytes)` (positive byte count or error), and `flush()` (success
or error). Calls are plain functions, not implicit-self methods:
`read(n)` returns a nonempty string of at most n bytes, `nil, 'eof'`, or
`nil, error_string`; `write(bytes)` returns a positive integer no greater than
the input length or `nil, error_string`; `flush()` returns true or
`nil, error_string`. The string `eof` is reserved for read EOF. Partial I/O is supported; adapters handle interrupted
OS calls and must not return empty strings in a busy loop. No close is invoked.
Options configure limits and MCP host instructions describing application APIs;
evaluation always uses the existing interpreter's global environment.

The lifecycle return record contains `reason` (`close_requested|eof|transport_error|handler_error`),
`acknowledgement_sent` (true only if the close acknowledgement was written and
flushed successfully), optional diagnostics, optional `close_request_id`,
`pending_messages`, and
`pending_bytes`. `pending_messages` is an ordered list of complete unprocessed
trailing frames as raw JSON strings, excluding their newline delimiters.
`pending_bytes` is the raw incomplete trailing frame, or an empty string.
This representation preserves messages without executing, re-encoding, or losing
information during JSON decoding. The parent can replay the complete frames in
order and then resume the partial frame. Bytes still buffered inside a
parent-owned adapter remain there and must not be duplicated in this record.
The standard worker wrapper
exits after return; custom parents choose their continuation. Validate adapters
against the host's actual embedding API during integration.

Internal worker traffic uses versioned newline-framed private ready/execute/
result messages on dedicated descriptors, not a second public MCP connection.
Internal execution generations associate timers, replies, and cancellations
with their original execution without exposing task IDs. Standard streams do
not carry control messages.

### 14.6 Event ordering and startup records

Dispatch is a single acceptance transition: reserve the idle session, invalidate
the old result, assign an internal execution generation, and arm deadlines
before writing the execute command. Transmission is bounded/nonblocking in the
manager. Invalid or busy calls do not perform this transition. Close/kill cannot
dispatch a buffered execution after termination has begun.

On worker exit or EOF, drain currently available control bytes up to the frame
bound before classifying an unfinished execution. A complete valid result
already available in the pipe can win over exit notification even if process
exit was observed first. Do not wait for future bytes or inherit an unlimited
drain from descendants. A hard deadline already reached, or an accepted kill
of an active execution, freezes that outcome; late worker results cannot undo
it. Receiving and validating completion before the deadline freezes the result
and disarms its timer. A completed execution's outcome never changes because
its idle worker is subsequently killed. Session lifecycle may still change.

For fatal cleanup, resolve already-pending requests after bounded cleanup so
the response can report whether exit was confirmed. Cancellation suppresses the
cancelled request's response but resolves other waiters. If cleanup reaches its
30-second bound, preserve the original timeout/kill/failure cause, include the
unconfirmed-exit notice, and remove the session. Waiters already bound to a
completed result retain that result under single-consumer rules even if kill
arrives before it is sent. A successful kill response does not consume an
unrelated waiter's recorded terminal result.

Startup uses bounded private protocol messages with `protocol_version: 1` and
an allocation generation: `file_created` (path), `ready` (effective cwd), or
`startup_error` (creation reason and diagnostics). Report a created file before
proceeding to another potentially blocking setup step. If a worker dies between
creating a file and reporting it, the manager cannot know the complete set:
return only reported paths and `created_files_complete: false`. Do not infer
ownership from a path's existence or delete such files. Ready after abort is
ignored. Spawn/cwd/stdio/handshake errors are all session_creation_error variants.
Execute commands carry code, JSON args, and an internal generation; results
echo that generation. Unknown, duplicate, malformed, or stale replies may not
complete another execution; protocol corruption disposes of that worker.

### 14.7 Discovery text requirements

Tool descriptions must teach the following at the point of use:

- Execute: omitted/null session ID creates a new interpreter; globals persist,
  locals do not; explicit return is required; another accepted execution
  discards an unread preceding result; no automatic output capture exists.
- Wait: zero polls; null waits indefinitely; default is ten minutes; terminal
  retrieval consumes the result, while a pending response does not. Request
  cancellation kills the session, unlike a wait deadline.
- Kill: destroys state, is synchronous best-effort disposal, and leaves no
  history. Unconfirmed OS exit is surfaced without failing the kill operation.
- List: only existing sessions, not history. An unknown session after async
  work does not imply its code never ran or that retrying side effects is safe.
- Handler close: acknowledges and returns control without closing the transport
  or changing host state; the parent decides what happens afterward.

### 14.8 Completion checks

In addition to section 8, implementation validation must cover:

1. Startup timeout while a child is blocked opening a supplied path; manager
   continues handling other sessions and records partial file creation honestly.
2. Result written before worker exit but processed after exit notification;
   deadline/kill races obey the authoritative outcome ordering above.
3. Two waiters racing for one successful or failed payload; exactly one consumes
   it and the other receives result_unavailable with the execution status.
4. All ordinary request slots occupied by waits while kill and cancellation
   still work through bounded reserved control capacity.
5. Worst-case JSON escaping and compatibility-text duplication near result
   limits; a permitted result fits without disconnecting unrelated sessions.
6. Data conversion errors report useful JSON Pointers, preserve prior side
   effects, and never leak partially encoded values or invoke metamethods.
7. Client disconnect during startup, execution, and response transmission;
   disposal is bounded and no session metadata survives cleanup.
8. A simulated worker that cannot be reaped in time yields successful kill
   with process_exit_confirmed false, no retained session, and no false death claim.
9. New stdout/stderr files never overwrite existing paths; cwd resolution and
   sharing a single output file follow the creation contract.
10. No print/io overrides or automatic output capture in either direct or
     managed execution; explicit client Lua capture remains possible.

### 14.9 Unexpected manager termination

`MANAGER_LIFECYCLE_DESIGN.md` defines required standalone lifecycle hardening.
SIGINT/SIGTERM, client disconnect and caught fatal errors enter idempotent,
bounded cleanup, including partially constructed workers. A dedicated independent
POSIX guardian owns OS worker spawning/reaping and disposes of workers after
manager-only crash or SIGKILL, including non-yielding Lua/native execution.
The manager remains logical session owner; guarded ownership precedes readiness
and user-code execution. Worker pipe EOF or Lua finalizers alone are insufficient.
Guardian loss is fail-closed; simultaneous manager/guardian loss, exceptional OS
inability to terminate, deliberate trusted-code interference and arbitrary
descendant trees retain the documented guarantee limits. Existing 30-second
cleanup fallback applies. No embedded-handler ownership or signal policy changes.
