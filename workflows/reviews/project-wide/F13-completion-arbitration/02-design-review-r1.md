# F13 design review

Required changes:

1. Select one authority model in this reviewed document. 'Prefer ... if ... otherwise select' leaves the central policy unresolved. The focused two-boundary model is not rejected in principle, but must be explicitly chosen and reconcile SPEC's recorded-completion preservation language rather than waiting for executor analysis.
2. Provide a concise outcome table for timely guardian validation with delayed/partial relay, kill and cancellation accepted before manager application, manager-recorded completion before response commitment, and stale generations. State whether a lifecycle summary alone records completion before its payload is fully available under F02.
3. Specify which fields/events are authoritative and how F02 prevents control priority from accidentally changing the chosen completion boundary. Preserve cancelled-response suppression, other waiters' single-consumer outcomes, and hard-deadline eligibility.

No new owner decision is needed merely to finish the proposed design. Escalate only an actual contradictory owner requirement, not the existing implementation's preference.

VERDICT: CHANGES_REQUESTED
