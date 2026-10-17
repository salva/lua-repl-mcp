# F13 plan review, round 2

Required change: incorporate the split completed-kill/completed-cancellation row and explicitly test cancellation after manager application but before response commitment. Assert no worker termination, preserved result/ordinary response and reservation, duplicate-ID rejection while it remains outstanding, and normal ID release after commitment. Keep the existing pre-application cancellation suppression case distinct.

The selected authority, partial-payload tests and delayed-relay timeout preservation are otherwise settled. Update only the normative ambiguity being resolved; do not rewrite the already-explicit completed-cancellation rule into new behavior.

VERDICT: CHANGES_REQUESTED
