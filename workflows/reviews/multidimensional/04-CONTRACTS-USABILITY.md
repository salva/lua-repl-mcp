# Astra contracts, documentation and installation review

Reviewer `openai/gpt-6-astra`, session `ses_eb45f1eb7ffeKOHo64az2MUyDk`.
Pinned source `701320b`; faithful condensed receipt, not automatic acceptance.
Inspected instructions, SPEC§15, schemas/examples, both root guides, all site pages,
build/staging, rockspec and relevant discovery/configuration. No builds, installs,
browser/process tests, original checkout/state/credentials/services. Source review
does not establish built-site or platform qualification.

## Findings

- **Existing F05, medium:** call embedded repl_close with `{unexpected=true}`
  following initialization/discovery. Generic error wrapper adds status=failed,
  forbidden by advertised close error schema. See
  [protocol.lua:76](../../../lua_repl_mcp/protocol.lua#L76)–78,
  [errors.lua:57](../../../lua_repl_mcp/errors.lua#L57),
  [api.json:127](../../../docs/schemas/api.json#L127)–134, plus overflow path25–29.
  Use tool-appropriate existing constructors and validate emitted errors. Small
  shared context helper only if needed; no error framework. Source confidence high.
- **Existing F10, medium:** source-guide links resolve to nonexistent site-docs
  copies, only becoming valid after staging:
  [embedding.md:10](../../../site-docs/embedding.md#L10),
  [reference.md:18](../../../site-docs/reference.md#L18)–23,
  [getting-started.md:31](../../../site-docs/getting-started.md#L31),
  [build_website.py:82](../../../docs/build_website.py#L82)–85.
  Repository-correct relative links plus small deterministic staging rewrites;
  check source/staged destinations/fragments/downloads. README's earlier root
  failure is already changed; no built-site failure claimed. No toolchain change.
- **New DOC01, low:** [embedding.md:58](../../../site-docs/embedding.md#L58)–65
  mentions evaluator options without accepted keys, unlike
  [limits.lua:4](../../../lua_repl_mcp/limits.lua#L4)–14.
  Unknown guesses produce handler_error. Document max_bytes, max_depth and
  diagnostic_bytes, units/defaults/loss-notice minimum and one valid serve example.
  Optional compact table; no configuration mechanism or CLI change. Exercise
  documented valid options plus one invalid configuration. Confidence high.

## Strengths and reconciliation

Guides distinguish embedding/manager ownership, explicit returns/globals, destructive
cancel, single consumption and effects. Source installation does not invent registry
availability; pure copy avoids natives. Site staging allowlists exclude work/spec.
Previously reported **F12 evidence overstatement is corrected** in
[WEBSITE.md:128](../../../docs/validation/WEBSITE.md#L128)–150; do not reopen it.
Linux/Lua5.4 qualification and POSIX targeting are distinguished, with pure-handler
5.5 historical evidence separately scoped. No new platform proof is claimed.

Owner semantics/user-work boundary should remain. Focused errors/links/options
repairs justify no compatibility machinery, publication expansion or repeated
campaign. Historical approvals/sunk toolchain effort are not proof either way.
