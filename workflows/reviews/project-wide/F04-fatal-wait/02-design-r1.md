# Resolve wait expiry against fatal disposal

Focused option: prioritize an established fatal outcome over an uncommitted
expired-wait response. One-level-up option: explicit generation-bound response
decision state at wait expiry, fatal transition and response commitment. Choose
the smallest explicit state representation that preserves already-committed
responses and single consumption; do not add public IDs or replay results.
Align decision boundaries with F13 and public error/result construction with F05.
