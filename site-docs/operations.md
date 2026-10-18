# Operate safely

## Choose cwd and output

`session_create` options or execute's `create_options` select `cwd`, stdout and
stderr paths. Paths resolve against the selected cwd. Output paths must not
already exist; they are exclusively created, never overwritten. Stdout/stderr
may share one newly created file. Startup failure may leave reported partial
created paths; inspect those before retrying. Defaults send output to `/dev/null`.
Printed output never automatically becomes MCP results. Protocol stdout must
contain only newline-delimited JSON-RPC, not diagnostics.

## Resource defaults

These are bounds, not a sandbox or guaranteed allocation. CLI takes no limit
switches; library configuration must maintain coupled capacities.

| Bound | Default |
| --- | --- |
| Input frame | 16777216 bytes (16 MiB) |
| Encoded values | 16777216 bytes (16 MiB) |
| Combined diagnostics | 65536 bytes |
| Data depth | 128 |
| Internal worker frame | 67108864 bytes (64 MiB) |
| Public response | 134217728 bytes (128 MiB) |
| Queued output | 268435456 bytes (256 MiB) |
| Sessions | 64 |
| Ordinary admitted requests | 256 |
| Control slots / kill reserve | 32 / 8 |
| Default wait | 600000 ms |
| Hard execution timeout | None unless specified |

## Lifecycle and shutdown

Sessions are owned by the client connection. EOF/disconnect initiates disposal.
SIGINT/SIGTERM request bounded manager shutdown. An independent POSIX guardian
owns worker spawn/reap and supervises lifetime on abrupt manager death, including
blocked Lua/native work. Progressive disposal retries TERM over 20 seconds, then
KILL over 10 seconds at one-second intervals, stopping on confirmed exit.
At the 30-second total bound, unconfirmed children are abandoned with warnings
and resources released. Inspect confirmation; best effort is not proof of exit.
Guardian failure is not a promise of automatic worker disposal in every OS failure.
Arbitrary descendant process trees are not sandboxed or guaranteed cleanup.

Embedded hosts own their own lifecycle: manager signal/kill policy does not
apply to them. Close returns control without closing handles or clearing state.

## Client deadlines and trust

A client may time out before the requested wait completes, close the connection
and lose unrelated sessions too. Use asynchronous execute and bounded polling;
wait expiry does not kill work, while accepted active-request cancellation does. Completed-request cancellation
is inert. No keep-alive guarantee
or durable reconnect semantics exist. Filesystem/network access is the host's,
and user code can exhaust resources or leak capabilities. Do not accept untrusted
code or share privileged credentials. No website endpoint executes Lua.
