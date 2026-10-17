# Reviewed subsystem map

Snapshot `701320b`; all four reviewers used this same baseline, not moving source.

| Layer | Files | Purpose and boundary |
| --- | --- | --- |
| Embedded entry | lua_repl_mcp/handler.lua, stream.lua, protocol.lua | Pure Lua; host-owned adapters/state, explicit lifecycle handoff |
| Evaluation/data | evaluator.lua, codec.lua, contracts.lua, errors.lua, limits.lua | Trusted host globals; strict JSON, explicit results and diagnostic bounds |
| Managed public entry | server.lua, manager.lua, transport.lua | One MCP connection, sessions, request reservations and commit-time consumption |
| Worker lifecycle | guardian.lua, worker_supervisor.lua, worker_main.lua, worker_protocol.lua, posix_backend.lua | Independent spawn/reap, private framing and progressive disposal; native dependencies excluded from handler path |
| Public contracts | docs/SPEC.md, docs/schemas/api.json, docs/MCP_EXAMPLES.md | Normative behaviour and executable advertised schemas |
| Installation/user site | root guides, rockspec, site-docs/, docs/build_website.py | Embedded/managed installation and usage, staged allowlisted site |
| Qualification | tests/, docs/validation/, workflows/reviews/ | Boundary/process/installed oracles and honestly scoped evidence; work records are not public product guides |

Source paths above are relative to repository root under `lua_repl_mcp/` unless
otherwise qualified. Relations are descriptive, not prescribed new abstractions.
