# Separate operation errors from execution outcomes

Focused option: tool-aware error factories at each fallback site. One-level-up
option: a small shared public-result construction layer distinguishing operation
errors, execution outcomes and lifecycle acknowledgements. Choose shared factories
if they remove duplicated conditionals without inventing a generic result type.
Preserve wire schemas; F07 maps internal failure provenance into these shapes.
