# Reject malformed requests without session loss

1. Add false/null/scalar/envelope cases distinguishing -32700 from -32600.
2. Reserve outstanding IDs at ingress; reject duplicates without replacing or
   cancelling the original operation, binding extra ownership or consuming results.
3. Specify duplicate rejection correlation (prefer invalid-request with null ID
   where no unique second operation exists), and release IDs on all terminal,
   rejected and cancelled paths without blocking legitimate later reuse.
4. Live-test a duplicate while another session persists: first operation resolves
   once and unrelated state remains usable. Include saturation and cancellation.

Dependencies: F05 controlled errors; coordinate commitment with F04/F13.
Importance 4/5, transversality 3/5.
