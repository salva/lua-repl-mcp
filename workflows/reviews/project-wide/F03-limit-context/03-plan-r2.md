# Implement effective depth and byte accounting

1. Retain escaped valid-input, D200/140-level arguments, D200/170-level result,
   enlarged-ingress and missing-envelope regressions through actual handler and
   guardian-backed managed protocol ingress.
2. Implement immutable context and copier per design; assert user subtree D,
   tuples D+1, known wire wrappers D+8 for D1/default128/max512 and D+1 rejection.
   Enforce independent frame/value/response limits and coupled floors unchanged.
3. Validate fresh identity, null and empty-shape behaviour; reject cycles, sparse/
   mixed/unsupported keys, unsafe/nonfinite numbers, malformed UTF-8 and hostile
   metamethod tables without invoking metamethods.
4. Test original-wire byte accounting separately from canonical library-input
   counting; include escaped network data fitting I whose canonical form exceeds
   I. Do not bypass protocol.handle by submitting directly to transport.
5. Integrate F05 wrappers so all fallback replies are schema-valid and partial
   values never leak after effects. Run exact legal-max/default/custom tests,
   installed process resolution and contract checks on qualified Lua versions.

Dependency: F01 numeric correctness; F03/F05 integration is atomic before C/D.
Importance5/5, transversality5/5. No silent capacity shrink or schema relaxation.
