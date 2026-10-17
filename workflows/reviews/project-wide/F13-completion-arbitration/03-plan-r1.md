# Settle completion, kill and cancellation ordering

1. At design gate, choose and state the authority for completion recording versus
   request acceptance; compare the two designs against SPEC preservation rules.
   Resolve the choice before F02/F04 runtime changes, not by accidental test order.
2. Specify exact outcomes for result validated before deadline but relayed late,
   kill/cancel before relay, completion already applied, expired wait, queued
   response not yet committed, and stale execution generation.
3. Update normative contract and user lifecycle description consistently, then
   deterministic event-permutation tests with response/relay barriers.
4. Integrate the selected rule with priority control and single-consumer results;
   prove both direct public behaviour and installed delayed-relay process cases.

Dependencies: none for design; coordinate runtime with F02/F04. Importance 4/5,
transversality 5/5. Preserve explicit owner outcomes; an actual contradictory owner
requirement is the only reason to escalate rather than invent a compromise.
