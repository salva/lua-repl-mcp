# Locale-independent number conversion

Both public surfaces share the JSON codec. Formatting numbers with locale-aware
`tostring` can emit a comma separator, corrupting JSON and evaluator return count.
An embedding host legitimately selects its locale; resetting global locale would
violate host ownership. Correct finite numeric round trips must be locale-free.
Inspect parsing as well as formatting, including exponent notation and negative
zero. The locale dependency is historical implementation baggage, not a required
compatibility feature. Reproduce with a real available decimal-comma locale;
record unavailable locales as skipped, not passed.
