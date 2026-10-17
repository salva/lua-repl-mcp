# F02 plan review

Required changes:

1. Replace step 2's future topology qualification/choice with implementation steps for the concrete reviewed design. State its control-service work bound and measurable latency/cleanup assertions, including scheduling allowance rather than an unsupported real-time OS guarantee.
2. Test allocation expiry while its command is queued: no late spawn or implicit user-code dispatch. Test disposal accepted during a partial bulk frame and shutdown while report delivery remains blocked, preserving the original deadline.
3. Make the aggregate-result acceptance exercise the installed guardian-backed CLI, not only the native supervisor used by older U7 fixtures. Include retained/consumed results, another active session, and explicit kill/cancel control progress. A scaled deterministic proof may supplement but not replace the legal-default aggregate case.
4. Include bounded work inside bulk serialization/parsing, result acknowledgement/replacement races, and removal of superseded snapshot machinery. Depend on the finalized F13 rule and F11 containment.

VERDICT: CHANGES_REQUESTED
