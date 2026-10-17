# Saivage deployment and launch

## Authorized scope

The operator authorized a separate instance, copying credentials from the
designated operational reference, and autonomous Run after specification and
plan review. Review receipts are in `REVIEW.md`; the root objective is in
`LAUNCH.md`. Product requirements remain in `docs/`.

## Deployment

| Item | Configuration |
| --- | --- |
| Container | `saivage-lua-repl-mcp`, classic LXC, Ubuntu 24.04 amd64 |
| Control room | `http://10.0.3.18:8080/` (DHCP; verify current address before operation) |
| Project | Host `/home/salva/g/ml/lua-repl-mcp` → `/work/lua-repl-mcp`, writable |
| Runtime | Dedicated release `39ffe231` copy mounted read-only at `/opt/saivage` |
| Host runtime source | `/home/salva/g/ml/tmp/lua-repl-mcp-container-setup/release-39ffe231` |
| Service | `saivage.service`, Node 24, guest user `salva` UID/GID 1000 |
| Workflow | Fresh bundled `classic-typed`; independent identity/cards/history |
| Routing | Planner Astra; Analyst, Oversight, Reviewer, Executor and compaction Sol |
| Credentials | Selected source profile copied into ignored local auth store, mode 0600 |
| Access | Port 8080 host-only via guest nftables; no guest SSH |
| State | Project-local `.saivage/` and `.saivage-work/`, ignored by Git |

The reference project's active release and provider/model settings were inspected;
only selected credentials and provider/model/compaction settings are copied.
No existing cards, conversations, history, or product prompts are reused.
Deployment scripts and private logs are outside Git under the setup directory.
The runtime source is an active mount dependency; do not remove it while deployed.

## Operation commands

```bash
sudo lxc-info -n saivage-lua-repl-mcp
sudo lxc-attach -n saivage-lua-repl-mcp -- systemctl status saivage.service --no-pager
# Use the currently reported DHCP address:
curl -fsS http://CONTAINER_IP:8080/health/ready
```

Use normal Analyst/Run/Stop controls for autonomous execution. Starting/restarting
the service is not equivalent to starting the project. Verify actual returned
child-agent tool activity before claiming that implementation has begun.

The provisioning baseline supplies Lua 5.4/dev headers, LuaRocks configured for
5.4, C build tools, Python/jsonschema, Git, and Node/npm. This is not qualification
of luaposix, JSON codecs, additional Lua versions, or product runtime correctness;
the implementation plan owns those checks. Executors may install dependencies
inside this dedicated guest, but must not modify its runtime release or siblings.

## Verification and launch receipt

Verified 2026-10-17 before autonomous Run:

- Fresh environment initialized with the supported `init --profile classic-typed`
  CLI. Template agent/session identities preserved; only routing/provider and
  compaction settings imported, with selected credentials kept private.
- Dedicated runtime copy compared byte-for-byte with its source before mounting.
- Host and guest health/readiness passed. The control room rendered and connected
  successfully, with execution initially stopped.
- Service and nftables survived a full LXC stop/start. Access from another
  container was rejected before and after restart; host access stayed available.
- NIC MAC `c2:2f:f2:f0:9c:c4` persisted in container configuration; address stayed
  `10.0.3.18` across restart.
- Guest-user toolchain checked: Node 24.16.0, npm 11.13.0, Lua 5.4.6, LuaRocks
  defaulting to 5.4, Git identity inherited from the operator's repository config.
- `python3 docs/check_contracts.py` passed inside the container: 14 schemas,
  seven official MCP Tools, two discovery results, 23 examples, 125 regressions.
- Auth store mode is 0600; `.saivage/` is ignored and no credentials are tracked.

Evidence: `tmp/lua-repl-mcp-container-setup/deployment-verification.json` and
private setup logs under the workspace. Provisioning fixed private umask-created
parent directory traversal permissions before launch; no runtime source change.

The supported Analyst `POST /api/chat` request accepted the root implementation
brief and called `start_project` successfully at **2026-10-17 09:41:42 UTC**.
Root Planner activated `card-a`, **U1 pure-Lua contracts, strict codec and
evaluator**. At 09:43 UTC `/api/state` reported running with current card `card-a`;
`agent:executor:card-a` was active and busy.

The child's current conversation segment contains executed successful
`run_command` calls from 09:42:23 onward, successful reads, and a successful
`write` at 09:43:07. One rejected read and one failed skill lookup also remain
in the evidence; they were followed by successful work and are not represented
as completed effects. This verifies real child execution, not completion of U1
or passing product runtime tests.

Launch evidence in the setup directory: `launch-response.json`,
`running-state.json`, `agents.json`, `root-children.json`, and
`child-executor-evidence.json`. Autonomous work is now active; avoid editing its
source/test files or generated runtime state concurrently.
