# Validate all public failure shapes

1. Reproduce `repl_close(arguments=false)` and forced overflow on each tool.
2. Define constructors for operation errors versus identified execution outcomes;
   omit execution status/metadata when not applicable.
3. Audit protocol, handler, client transport and manager fallback sites, including
   post-effect serialization failures and unknown sessions.
4. Validate actual returned structuredContent against every advertised output
   schema; include malformed arguments, overflow, startup/transport failure.
5. Run contract checker and live direct/managed error recovery tests.

Dependencies: coordinate F03 wrapping; exposes mapping surface for F07.
Importance 4/5, transversality 4/5. Do not repair by widening schemas arbitrarily.
