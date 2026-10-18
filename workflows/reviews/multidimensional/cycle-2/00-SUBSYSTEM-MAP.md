# Cycle 2 subsystem map

Source baseline `a600754`; paths relative to repository root.

| Boundary | Main files | Reviewed responsibility |
| --- | --- | --- |
| Host attachment | lua_repl_mcp/handler.lua, evaluator.lua, protocol.lua | Pure blocking adapters, host globals, accepted options, direct discovery and explicit results |
| Data/error conversion | codec.lua, contracts.lua, errors.lua, limits.lua | Raw copying, wire versus canonical admission, per-value depth and bounded recoverable errors |
| Public session policy | manager.lua, client_transport.lua | Request resolution/cancellation, ID ownership, capacity admission, application versus commitment |
| Process ownership | guardian.lua, worker_supervisor.lua, worker_main.lua, worker_protocol.lua | Independent control/liveness and bulk, immutable allocation IDs, retirement, spawn/reap and original disposal origins |
| Evidence/user interface | tests/, docs/schemas/, site-docs/, docs/validation/, workflows/reviews/project-wide/BATCH3-INTEGRATED-MATRIX.md | Actual response compatibility, concurrent-control oracles, installed/current-client evidence, documentation claims |

Established architecture remains; no new layers prescribed by this map.
