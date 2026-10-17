# F02 — Manager-crash test accepts an unreaped worker

Reviewer-local T01. **Accept narrower oracle; medium severity, test-local impact.**
Source: [u12_lifecycle_red.py:84–93](../../../tests/u12_lifecycle_red.py#L84),
[u12_matrix.py:79](../../../tests/u12_matrix.py#L79),170–173.
Zombies count as not alive; that correctly tests termination but does not prove
guardian reaping before external cleanup. SPEC requires both. This does **not**
establish an actual product reap defect or invalidate unrelated termination proof.

Extend one contained manager-only-crash case to require original worker identity
to disappear before harness cleanup, using PID/start-time identity rather than
PID absence alone. Do not require guardian disappearance or signal arbitrary PIDs.
Keep external cleanup on all paths. Demonstrate a controlled omitted-reap mutant
fails; then qualify real installed guardian. A narrow adopted-worker observer is
an alternative only if existing observations cannot distinguish ownership.
Fold into existing U13 F02 acceptance; no extra architecture track/matrix.
Reconcile tests already changing in Saivage. No fix performed.
