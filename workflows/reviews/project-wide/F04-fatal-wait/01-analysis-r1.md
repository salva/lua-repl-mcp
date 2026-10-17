# Preserve fatal outcomes for outstanding callers

Wait expiry does not kill execution, but a caller still pending during fatal
cleanup must not receive an irretrievable running state after session disposal.
Distinguish an already-committed pending response from a waiter not yet resolved.
Timestamp reconstruction currently obscures that distinction. Single consumption,
immutable outcomes and truthful side effects are correctness requirements; the
current branch ordering is not a compatibility contract.
