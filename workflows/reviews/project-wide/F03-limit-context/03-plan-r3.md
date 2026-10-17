# Implement consistent limits through real dispatch

1. Retain escaped-byte, deep args/results and enlarged-ingress failures through
   actual protocol.handle on direct and guardian-backed managed interfaces.
2. Implement D/D+1/D+8 context and raw copier. Assert limits at D1/128/512 and
   one-over rejection; include fresh identity, null/empty shapes, cycles, malformed
   keys, unsafe/nonfinite numbers and invalid UTF-8. Valid raw metatable-bearing
   tables pass with zero metamethod calls; invalid raw data fails likewise.
3. Capture validated immutable code/args/options spans and bind private DTO to
   the exact allocation/generation. No full request forwarding or trusted raw-text
   caller API. Library canonical counting is separate from original network bytes.
4. At a legal tight custom floor with small V, dispatch original escaped string
   input and short fractional tokens whose canonical re-emission expands. Prove
   a real worker enters code exactly once and returns correct values under that
   configuration. Test altered/stale span/identity rejection and fresh Lua args.
5. Integrate F05 valid fallbacks; test max/default/custom fit and configured depth
   through worker/private/public envelopes. Run installed/native and contracts
   on qualified versions without silently reducing input/result allowances.

Dependencies: F01 numeric conversion; atomic F03/F05 interface before C/D,
F02 carries preserved token bodies. Importance5/5, transversality5/5.
