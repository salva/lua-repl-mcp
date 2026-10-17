# One explicit limits and structural-validation boundary

Focused alternative threads defaults through encode/decode cloning. Select one
validated immutable context plus structural copying, avoiding serialization just
to clone. Keep configured user depth D in1..512; default128. A container root is
level1; scalar leaves consume no container level. Each argument value and each
returned value has at most D nested containers. Positional argument/return tuple
arrays are structural envelopes and add1, not deducted from user depth.

Raw public envelopes and private result wrappers allow D+8 container levels;
validate the known envelope separately and apply D to data subtrees. Return tuple
normalization allows D+1. Response/public/private encoding uses D+8, with actual
wrapper shape asserted to fit that headroom. Unknown nested fields do not bypass
envelope/schema validation. Supported max D512 must round-trip both interfaces
through actual protocol handling, not merely evaluator calls. Clarify this
precise counting in SPEC rather than claim historical ambiguous counting mandated it.

The copier uses next/rawget/rawequal, never metamethods; allocates fresh tables,
preserves trusted decoded shape metadata and null identity, validates cycles and
per-value depth, string keys/UTF-8, finite safe numbers, dense arrays and permitted
value types. Reject unsupported keys/types and invalid internal shape markers;
empty unmarked library tables follow the documented object rule. No user
metatable is copied or invoked. This validation remains required for Lua callers.

For network ingress, I counts original UTF-8 frame bytes excluding delimiter,
once only, before decode. Structural copying does not reapply a canonical-wire
ceiling to decoded network data. For direct Lua-library calls with no frame,
define I as canonical JSON bytes of the tool-arguments object, counted boundedly
without allocating a whole encoded clone. Record this distinct library rule in
the public library contract; internal provenance is carried by the context, not
a user-settable flag allowing callers to skip validation. V counts complete
encoded values array; worker/response/output each use their approved independent
budget and existing coupled floors. Any failed wrapper must yield a schema-valid
bounded error (F05), never an incomplete JSON-RPC envelope.

This removes accidental defaults while preserving strict conversion and real
limits. It is one context/copier, not parallel legacy validation paths.
