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

Provisioning and service/runtime checks are in progress. Record observed address,
readiness, restart confinement, and supported Analyst/child execution evidence
here after verification; configuration alone is not a successful launch.
