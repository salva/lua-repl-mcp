# Implement locale-safe JSON numbers

1. Reproduce `return 1.5` corruption and object-number failure; retain assertions
   for value, type and exact return count. Inspect decoder locale sensitivity.
2. Implement codec-local numeric conversion without changing the host locale.
3. Test decimal fractions/exponents, integers, negative zero, range boundaries
   and invalid/nonfinite input under C and available decimal-comma locales.
4. Run core/evaluator/direct and installed-manager JSON tests on qualified Lua
   versions; record exact locales/versions and skips. Preserve existing limits.

Dependency: none. Importance 5/5, transversality 4/5. Restore the prior batch only
through a new reviewed corrective commit if regression occurs; never reset others' work.
