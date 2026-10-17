# F13 design review, round 2

The explicit manager-authority model and summary-versus-payload application rule resolve the previous deferred decision. One new contract contradiction must be corrected:

The row 'Manager recorded completion before kill/cancellation, response not yet committed' says to destroy the idle worker/session and suppress cancellation's response. Explicit kill may dispose of that idle session, but cancellation of an already completed request must not kill it. Snapshot SPEC §11.3, lines709-714, expressly makes completed request IDs non-destructive; manager.lua:170-172 implements that distinction. This is not the ambiguous guardian-validation-versus-manager-application boundary addressed by F13: in this row the manager has already recorded completion.

Required change: split kill and cancellation in this row. Preserve explicit kill disposal and recorded result access. Make cancellation after manager-recorded completion inert under the existing contract, retaining the normal outstanding response/reservation until commitment; do not release/reuse its ID by treating it as suppressed. Keep pre-application accepted cancellation destructive and response-suppressing as already selected.

Historical-baggage lens: correcting terminology must not introduce a new destructive cancellation behavior merely because kill and cancellation were combined in the review table. No broader authority redesign is requested.

VERDICT: CHANGES_REQUESTED
