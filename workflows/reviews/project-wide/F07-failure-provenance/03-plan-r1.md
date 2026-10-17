# Make failure responses truthful and schema-valid

1. Inventory private failure causes and map each to allowed public codes/reasons,
   stage, execution identity and optional observed exit_code/signal.
2. Preserve sanitized bounded startup diagnostics and distinguish failed chdir
   from stdio setup. Align worker protocol validation with documented reasons.
3. Test actual nonzero exit/signal, bad cwd/redirection, handshake corruption,
   startup EOF and transport failure; never claim unobserved OS exit details.
4. Validate public errors against schemas and ensure primary failure survives
   cleanup errors; run installed startup/process/live MCP suites.

Dependencies: F05 constructors; coordinate guardian record changes with F02.
Importance 4/5, transversality 4/5.
