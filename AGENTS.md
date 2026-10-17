# Lua REPL MCP development

- Implement the reviewed requirements in `docs/SPEC.md`, with executable
  contracts in `docs/schemas/api.json` and examples in `docs/MCP_EXAMPLES.md`.
  Follow the dependency order and evidence gates in `docs/PLAN.md`.
- Deliver working software, not another unbounded specification review. Raise
  only concrete contradictions or dependency blockers; continue independent work.
- The handler is pure Lua, blocking, and single-threaded in the existing global
  environment. The POSIX manager owns independent worker processes and its event
  loop. Keep manager/native dependencies out of the handler import path.
- No automatic output capture, no implicit expression returns, no public task
  IDs, and no transport closure by the handler. Preserve the documented
  cancellation, result-consumption, JSON-conversion, and cleanup semantics.
- Use meaningful boundary tests and real POSIX processes as required by the plan.
  Validate schemas with `python3 docs/check_contracts.py`; schema checks alone
  do not establish runtime correctness. Record tool/runtime versions accurately.
- Keep state and credentials project-local and ignored under `.saivage/` and
  `.saivage-work/`. Never commit credentials or print them in reports.
- Commit completed changes promptly. Do not push or publish without permission.
  Use the configured repository Git author/committer identity.
- Stay within this project and its dedicated container. Do not modify sibling
  projects, deployment releases, host configuration, or other services.
  Operational setup/launch details belong in `workflows/`, not product docs.
