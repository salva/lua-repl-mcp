# Locale-safe numeric boundary

Focused option: normalize the formatter's numeric decimal marker using a
qualified locale-independent conversion, without changing process locale.
One-level-up option: centralize numeric token formatting/parsing in codec helpers
and route every JSON numeric path through them. Choose the centralized boundary
if it stays inside the codec; do not introduce another JSON library or global
locale mutation. Preserve numeric range, subtype and rejection semantics. Verify
parser and emitter round trips rather than assuming only formatting is affected.
