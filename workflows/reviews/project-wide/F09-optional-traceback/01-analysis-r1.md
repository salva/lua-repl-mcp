# Optional diagnostic facilities

Embedding hosts can omit debug while providing required Lua execution/standard
primitives. The contract qualifies traceback availability; unconditional import
of debug.traceback is therefore an accidental host dependency. Preserve useful
bounded error strings without demanding debug or masking runtime failures.
Do not expand this into support for every arbitrary stripped Lua environment.
