# Preserve observed lifecycle provenance

The public contract describes startup reasons, diagnostics and observed process
exit metadata. Private ownership layers already observe some of this but lose
or mislabel it. A client must distinguish cwd setup, stdio, handshake, transport
and execution without receiving private enum values or invented exit facts.
Typed propagation is a correctness need; inconsistent string labels are baggage.
Sanitize and bound diagnostics without discarding relevant observed causes.
