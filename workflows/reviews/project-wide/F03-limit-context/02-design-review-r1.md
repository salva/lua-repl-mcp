# F03 design review

Required changes:

1. Define the context's depth accounting at each boundary: raw public envelope, argument data, individual returned values, return tuple, private envelopes, and public wrapper. Specify allowance for envelope overhead and the configured maximum so 'thread limits' does not merely move the same hidden restriction elsewhere.
2. State the structural copier's validation obligations explicitly: raw traversal without metamethods, fresh tables, preserved null/array/object distinctions, cycle/depth checks, valid UTF-8 and safe finite numbers, and rejection of unsupported values/keys. Removing encode/decode cloning must not remove validation for Lua-side callers.
3. Define the byte-accounting rule for already-decoded/library inputs with no original frame. Do not silently impose a canonical-wire ceiling on network input while claiming original-byte semantics.

Keep this as one small context/copier boundary, not parallel compatibility paths.

VERDICT: CHANGES_REQUESTED
