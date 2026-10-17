# Make the acceptance runner own its failure boundary

1. Classify every fixture explicitly; remove u[1-7]* accidental U12 discovery.
   Historical reds require named expected assertion/status, not any-nonzero pass.
2. Implement external subreaper supervisor and inherited containment context;
   remove nested wrapper setsid/new-session ownership under supervision. Bound
   fixture and whole-driver deadlines with one surviving cleanup owner.
3. Inject timeout/crash of a nested wrapper and aggregate driver while fixtures
   run, including a deliberate new-session descendant and TERM-ignoring worker.
   Assert all owned groups/children are gone and immediate driver child reaped.
4. Inject partial response then stall, perpetual pending and early EOF; verify
   complete-frame/overall deadlines and bounded cleanup on assertion failure.
5. Run corrected combined installed suite, preserving outside-checkout module
   checks and reporting unsupported containment environments honestly.

Dependency: none, execute first. Importance4/5, transversality4/5. The product
guardian cannot serve as the supervisor of the test of its own failures.
