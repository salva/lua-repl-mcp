# Keep malformed requests from corrupting correlation

Invalid envelopes should produce controlled protocol errors, not terminate
unrelated managed sessions through internal assertions. JSON false is a valid
decoded value but not a valid request; decode success cannot use truthiness.
Duplicate in-flight IDs need explicit treatment that neither replaces the first
request nor consumes its result. Robust ingress is required despite trusted Lua
execution. Supporting ambiguous correlation is not a compatibility requirement.
