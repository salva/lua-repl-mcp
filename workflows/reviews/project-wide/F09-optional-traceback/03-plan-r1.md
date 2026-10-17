# Load and recover without debug

1. Fresh-process import handler with debug=nil, missing traceback and ordinary
   debug; run success and syntax/runtime-error-then-success sequences.
2. Capture optional traceback safely and preserve bounded error descriptions.
3. Document required host primitives versus optional diagnostics and validate
   copied pure-Lua installation without native imports.

Dependency: batch with F06 protected invocation and F07 provenance.
Importance 3/5, transversality 2/5.
