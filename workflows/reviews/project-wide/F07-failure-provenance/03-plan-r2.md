# Make failure responses truthful and schema-valid

1. Complete the F05/F07 mapping interface in batch B before evaluator/ingress
   changes. Preparation capacity = limit_exceeded/execution/not_started with
   usable idle session; ordinary runtime = lua_runtime_error/execution/started;
   transport = transport_error/transport/unknown unless a known execution state
   is available; creation = session_creation_error/creation/not_started with a
   permitted creation reason. Optional OS exit fields require actual observation.
   Never copy private reasons directly to the public enum.
2. Inventory remaining private causes and map code/reason/stage/identity once.
   In batch D preserve sanitized bounded startup diagnostics through guardian and
   distinguish failed chdir from stdio. Align private protocol reason validation.
3. Test actual nonzero exit/signal, bad cwd/redirection, handshake corruption,
   startup EOF and transport failure; never invent unobserved OS exit details.
4. Validate all public shapes and preserve the original failure through cleanup;
   run installed startup/process/live MCP suites after native propagation changes.

Dependencies: F05 constructors. Interface is delivered in B, consumed in C;
native/guardian propagation is implemented with F02 in D. Importance4/5,
transversality4/5. A small mapping replaces lossy labels, not an error framework.
