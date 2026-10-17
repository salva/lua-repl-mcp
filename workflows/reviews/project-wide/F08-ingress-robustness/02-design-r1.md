# Validate envelopes before binding

Focused option: detect duplicates and false-valued decode results before manager
entry, returning controlled protocol errors. One-level-up option: centralize
envelope/outstanding-ID validation at ingress with an explicit reservation and
release lifecycle. Prefer one ingress owner if it prevents duplicated bindings;
manager assertions remain internal invariant checks, never normal client control.
Choose a duplicate-ID rejection whose ID semantics preserve the original pending
request; test the exact wire policy rather than silently answering twice as it.
