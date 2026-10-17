# Implement the selected outcome boundaries

1. Clarify SPEC §7 completed-result preservation, §14.6 completion/deadline/kill
   rules and discovery/user lifecycle text with the chosen three boundaries:
   guardian validation evidence, manager logical application, public commitment.
2. Derive deterministic expectations from the outcome table before coding. Cover
   timely/late guardian validation, summary before/after partial bulk, kill/cancel
   before application, recorded completion before commit, expired wait and stale
   generations. Preserve suppression of cancelled RPC and other waiters' access.
3. Implement manager authority with F02's priority controls and payload ACK/discard;
   no future topology/authority choice remains for the executor.
4. Retain delayed-relay hard-deadline regression; update tests whose old wording
   conflates physical return/validation/application. Test guardian-backed installed
   partial-payload control races and single-consumer commitment with F04/F08.

Dependencies: fixed interface specified before C; runtime integrated with F02/D.
Importance4/5, transversality5/5. Historical assertions are evidence, not vetoes
over the explicit normative model; escalate only an actual owner contradiction.
