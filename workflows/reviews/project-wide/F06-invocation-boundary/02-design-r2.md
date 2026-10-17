# Protected invocation preparation with truthful errors

Focused alternative protects unpack in a closure; a VM-specific public argument
cap is the one-level-up alternative. Select the protected closure without an
invented public count. Capture a chunk-entry marker only after arguments have
been unpacked, at the entry of an invocation trampoline immediately before calling
the compiled user chunk. Errors before that marker are preparation failures;
syntax compilation keeps its existing lua_syntax_error classification.

For the demonstrated VM unpack/call-capacity preparation failure, emit existing
code `limit_exceeded`, stage `execution`, execution_state `not_started`, status
`failed`. A managed accepted execution remains idle and session_usable true;
direct attachment remains usable. No user-side effects are claimed or replayed.
Ordinary exceptions after the marker remain lua_runtime_error/execution/started.
Use F05 outer shapes and the F07 mapping interface established before this batch.

Error handler captures the original thrown value first. Optional traceback runs
inside its own protected call; if absent or failing, omit traceback and sanitize
the primary error instead. It must not become an error-in-error-handler substitute
for the primary cause. Do not promise recovery from catastrophic OOM or process
death. F09 supplies conditional capture, not a pluggable diagnostic framework.
