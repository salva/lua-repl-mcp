# Tool-specific operation errors

A client must be able to validate every advertised result, including invalid
arguments and fallback paths. Generic execution failures cannot represent close,
list or pre-session operation errors. Checked schema shape is an owner contract;
generic status injection is implementation baggage. Avoid schema relaxation to
match malformed existing output. Side-effect/identity metadata must only claim
an execution when one is actually identified.
