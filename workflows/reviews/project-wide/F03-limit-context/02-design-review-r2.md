# F03 design review, round 2

Depth accounting, structural validation obligations and network/library provenance resolve the earlier omissions. One concrete end-to-end fit contradiction remains:

Network input is admitted using original bytes, but subsequent internal execute encoding can expand it. For example, roughly 6MiB of JSON containing three MiB of newline characters spelled as backslash-n fits I; the current codec emits roughly 18MiB using six-byte escapes. With small V and D, a configuration at the unchanged worker floor I+V+6D+H permits only roughly 7MiB. Hidden clone limits may be removed, yet a legal execution still cannot fit its worker frame. Short fractional numeric tokens can also expand on re-emission; changing only newline escaping is insufficient.

Required change: specify how accepted original argument/code representations survive manager-to-guardian-to-worker transfer without this expansion, or supply a revised demonstrated capacity contract that accommodates expansion without lowering public allowances. The current simultaneous promises of original-byte admission, unchanged floors, and ordinary re-encoding are insufficient. Define how validated raw slices/segments, if selected, remain bound to the exact execution and are converted to fresh Lua argument tables. Do not carry an entire request envelope or arbitrary unknown fields as a worker command.

Historical-baggage lens: avoid another broad capacity increase merely to preserve serialization-as-copy. Preserve only the minimal original-wire representation needed for the proven fit requirement.

VERDICT: CHANGES_REQUESTED
