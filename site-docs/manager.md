# Work with managed sessions

Creation may select a literal `command` argv instead of the default interpreter.
See [custom hosts](custom-host.md) for same-Lua-state application integration.
The same session semantics apply, but destructive session operations then destroy
that application host process.

Each session is an independent persistent Lua worker. A session belongs to one
client connection. Globals/functions survive calls, but top-level locals and
consumed result payloads do not. There are no public task IDs or detached sessions.

## Choose a tool

| Tool | Use and expected outcome |
| --- | --- |
| `session_create` | Allocate idle state with optional cwd/output paths; save the new ID |
| `session_list` | Inspect this connection's sessions without consuming results |
| `session_execute` | Run once in an ID, or allocate if ID is omitted/null |
| `session_wait` | Wait for or consume a result in a concrete session ID |
| `session_kill` | Dispose of a concrete session ID and its state |

Input and output fields are defined by the [downloadable schemas](../docs/schemas/api.json),
not by client-specific tool prefixes. Missing/unknown IDs, invalid options and
busy sessions report operation errors; they are not permission to resubmit code.
Wait and kill reject null IDs. Create options and execution `create_options`
select [cwd and output files](operations.md#choose-cwd-and-output).

## Reuse a counter

Call `session_execute` with these tool arguments:

```json
{"code":"local n = ...; counter = (counter or 0) + n; return counter","args":[2],"wait_timeout_ms":1000}
```

On completion expect `[2]`. Retain the actual `session_id` and use it below:

```json
{"session_id":"<returned session_id>","code":"return counter","wait_timeout_ms":1000}
```

Expect `[2]` again. `local n` does not survive. Explicit returns are required;
`print(counter)` writes worker output, not a tool value.

## Start asynchronously and poll

Use `wait_timeout_ms: 0` on execute to return without waiting. A pending reply
means execution was accepted, not that it completed. Call `session_wait`:

```json
{"session_id":"<returned session_id>","wait_timeout_ms":1000}
```

Repeat wait on pending/running. It never reexecutes the code. Omission defaults
to 600000 ms; JSON null waits indefinitely. A client may impose a shorter own
deadline and disconnect. Prefer bounded polls for long work.

A terminal result is consumed exactly once by execute or wait. Save it when
received; later waits report `result_unavailable`. An accepted new execution
replaces any unread old result. A busy session rejects another execution.

## Deadlines, cancellation and disposal

`execution_timeout_ms` is a separate hard execution deadline; omission has none.
Expiry destroys the session. Accepted cancellation of an active request destroys
its associated managed session and suppresses that RPC reply. Cancellation of an
unknown, already completed or answered request is inert, including a completed
request whose response has not yet been committed. Cancellation is **not** a safe
substitute for stopping a wait.

Complete worker-result validation, manager recording and public response commitment
are distinct: data still in transit is not yet a recorded outcome. Kill or active
cancellation before manager recording can freeze disposal; an already recorded
result cannot be rewritten. Explicit kill still destroys an idle session's state,
while waiters already bound to its recorded result retain that result under the
single-consumer rules. A result is consumed on public response commitment, not
merely when the worker finishes.

Ordinary syntax/runtime/serialization errors usually leave the session usable;
check `session_usable`. A worker exit, kill, cancellation or hard deadline can
make it unavailable. Connection loss disposes of all connection-owned sessions.
A guardian supervises worker lifetime even if the manager abruptly dies; bounded
cleanup and exit confirmation are different claims. See [operations](operations.md).

## Recover without duplicating effects

For example `counter = counter + 1; error('stop')` may increment before failing.
If usable, inspect it with `return counter`; do not replay the mutation merely
because the response was an error. Conversion failures also do not roll back
execution. After losing the connection, establish a new one and create fresh
state rather than assuming an old ID remains usable.
