# Implement precise completion and destructive-operation ordering

1. Clarify SPEC §7 and §14.6 terminology plus user/discovery text for guardian
   eligibility, manager application and public commitment; leave completed-request
   cancellation (§11.3) explicitly inert.
2. Derive expectations from the selected outcome table. Cover validation before/
   after deadline, summary/partial payload before/after control, kill/cancel before
   manager application and explicit kill after recorded completion.
3. Separately test cancellation after application but before commitment: no worker
   termination, ordinary response/result and reservation preserved; duplicates
   rejected until normal commitment, ID reusable thereafter. Contrast active
   cancellation suppression and its separate ID-release path.
4. Implement F02 ACK/discard and F04 fatal/wait resolution against the same state
   transitions. Preserve delayed-relay hard-deadline regression and single consumer.
5. Run actual installed guardian partial-transfer/control races plus deterministic
   event permutations/stale identities; do not infer completion from raw return.

Dependencies: fixed contract before C, runtime integrated with F02/D and F08.
Importance4/5, transversality5/5. No deferred authority choice or new public IDs.
