# Effective limits, structural copies and fit-preserving wire spans

Select one immutable validated context and raw structural copier rather than
encode/decode cloning with independent defaults. D is user container depth1..512
(default128); root container is1, scalar leaves add none. Each argument/returned
value allows D; positional tuples add1; known public/private wrappers allow D+8.
Validate envelopes separately and assert actual wrapper headroom. Unknown fields
do not bypass schema validation. Preserve all approved byte/coupling floors.

Copier uses next/rawget/rawequal, fresh tables and trusted null/shape metadata;
checks cycles, depth, finite safe numbers, UTF-8, supported keys/types and dense
arrays. Valid raw tables with arbitrary metatables remain accepted without
invoking/copying metatables; invalid raw data is rejected, not metatable presence.
Empty unmarked library tables retain the documented object rule.

Network I counts original frame bytes once. Decoder retains immutable source
spans for only validated code string, args array and creation-options fields.
Build the private DTO by inserting those already-validated JSON tokens verbatim
under fixed private field names plus bounded generation metadata. Their disjoint
source bytes total<=I; do not carry public IDs, unknown fields or whole envelopes.
Bind spans to allocation/execution/transfer identities, validate their token types
and boundaries, and never accept arbitrary caller-supplied raw text as trusted.
The guardian/worker decode selected fields using the same validated context into
fresh Lua data; do not replace spans with expanded decimal/string re-emission.

Library input has no frame: validate/copy and boundedly count canonical JSON of
the tool-arguments object against I, then retain those canonical selected-field
tokens as immutable command spans. Internal validated provenance is not a user
flag permitting bypass. Do not recanonicalize legitimate network spans to impose
an unadvertised byte ceiling. The source span+fixed private overhead remains under
I+H, hence existing worker floor I+V+6*diagnostic_bytes+H, including tight custom
configurations with small V. This is representation preservation, not a capacity
increase or a change to args-as-varargs semantics.

V still counts encoded values tuple, worker/response/output use their own floors,
and normalization/wrapping depth uses D+1/D+8. All wrapper failures use F05 valid
bounded errors without partial returns. Structural validation remains mandatory
at worker trust boundaries even when immutable token bytes are preserved.
The focused alternative is larger conservative internal capacity; reject it
because preserving minimal validated original representation avoids amplifying
limits just to retain serialization-as-copy history.
