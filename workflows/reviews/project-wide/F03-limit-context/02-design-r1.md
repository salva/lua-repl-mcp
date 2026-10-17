# Validated limits context and structural copying

Focused option: thread all applicable limits explicitly into each existing
encode/decode/clone operation and handle wrapping failures. One-level-up option:
one validated per-connection context plus structural JSON argument copying that
does not serialize merely to copy. Choose the latter where it removes duplicated
wire accounting; preserve null sentinel, arrays and object distinctions and avoid
metamethods. Keep pure handler imports free of POSIX dependencies. Shared result
construction with F05 must return either a valid response or an explicit bounded
transport failure, never an incomplete JSON-RPC envelope.
