# Repair repository and site links together

1. Inventory README/source links and reproduce missing LLM/schema/example paths.
2. Make authoring paths valid from repository locations; derive deterministic
   stage rewrites from an explicit allowlist mapping.
3. Validate both source and built paths/fragments, including root README/LLM
   entry points, downloads and project-prefix hosting.
4. Run strict repeated builds, boundary scans and browser smoke on desktop/mobile.

Dependency: F11 safe harness. Importance 3/5, transversality 3/5. Publication is
operator-owned separately; source-link repair does not authorize deploy automation.
