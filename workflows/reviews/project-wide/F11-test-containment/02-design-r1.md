# Small explicit runner manifest

Focused option: exclude process fixtures from loose globs and patch each wrapper.
One-level-up option: an explicit manifest of fixture type, supported runner,
timeout/containment and historical disposition, using a small shared deadline
helper. Choose the manifest when it removes ambiguous discovery without building
a test framework. Group containment must never signal unrelated host processes;
record allowed platform assumptions for tests separately from product POSIX claims.
