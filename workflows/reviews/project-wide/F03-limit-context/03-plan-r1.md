# Make limits effective end to end

1. Retain escaped-input, depth200/140-level args, depth200/170-level result and
   enlarged-input reproductions, asserting exact envelope and schema validity.
2. Trace context from handler/manager options through ingress, argument validation,
   evaluator, worker records and public wrapping. Remove accidental defaults.
3. Replace encode/decode cloning with safe structural copying where appropriate;
   account original frame bytes separately from canonical output bytes.
4. Handle each encoding/wrapping error without leaking partial values; preserve
   already-executed side effects and honest execution metadata.
5. Test defaults/custom maxima/depths, escaped payloads, null/empty structures,
   configured bounds and installed native transport. Run schema and max-fit gates.

Dependency: F01 numeric boundary. Importance 5/5, transversality 5/5. Pair public
fallback changes with F05; no temporary schema relaxation or capacity shrink.
