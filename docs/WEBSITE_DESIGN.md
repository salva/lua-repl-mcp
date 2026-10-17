# GitHub Pages documentation website — design addendum

## Purpose and scope

Create a public-facing static documentation website for Lua REPL MCP, suitable
for GitHub Pages project hosting. Help an MCP client user install and operate
the session manager, and a Lua application developer embed the independent
handler. This adds documentation delivery, not runtime functionality.

The site must clearly distinguish the pure-Lua blocking handler from the POSIX
process-managing server. Do not present a browser-hosted REPL, remote execution
endpoint, public demo service, or credentials form. GitHub Pages serves only
static documentation; visitors' Lua code is never executed there.

## Content and navigation

1. **Home:** purpose, architecture diagram, principal features, current release
   status, links to installation and embedding, and a prominent full-access warning.
2. **Getting started:** Lua/POSIX prerequisites, clean LuaRocks installation,
   stdio manager configuration, and a minimal allocate/execute/kill example.
3. **MCP guide:** all five manager tools, implicit allocation, persistent globals
   versus locals, explicit return, JSON args/results, wait modes, consumed results,
   separate hard deadlines, destructive cancellation, and session cleanup.
4. **Embedding guide:** pure-Lua imports, exact read/write/flush adapter contract,
   host API access, dedicated descriptors, synchronous operation, close ACK and
   parent continuation, and buffered-message/partial-frame handoff.
5. **Data and errors:** null sentinel, table mapping, numeric range, unsupported
   values, serialization failure after side effects, and actionable error examples.
6. **Operations and limitations:** cwd/redirection, current resource defaults,
   trust/system privileges, no automatic output capture, client timeout pitfalls,
   and links to relevant public upstream issues without overstating fixes.
7. **Reference:** reviewed specification, tool schemas, wire examples, tested
   versions, local build/test commands, and contribution guidance.

Use concise task-oriented prose and copyable code blocks. Explain which tools
belong to each surface; do not show session IDs on the embedded-handler API.
Examples must use real supported APIs and remain consistent with the executable
contracts. Preserve accessible heading order, descriptive links, responsive
navigation, keyboard use, and readable code blocks on small screens.

## Build and source layout

Use MkDocs with a pinned supported version and its bundled theme initially; no
custom frontend framework or Lua/runtime dependency is needed for documentation.
Keep authored website pages under `site-docs/`, configuration in `mkdocs.yml`,
Python documentation dependencies in a dedicated pinned requirements file, and
generated output in ignored `site/`. Document a clean-venv local build command.

Do not copy the entire repository or `docs/` directory into the public artifact.
Build an explicit content tree: copy selected public reference files into a
temporary documentation staging directory, including SPEC.md, MCP_EXAMPLES.md,
and schemas/api.json, with link paths adjusted and validated by the builder.
Keep reference generation deterministic and read-only with respect to sources.
Author guides for navigation; do not create a second independently maintained
specification or schema. Changes to generated reference files must come from
their authoritative source.

Exclude `.saivage/`, `.saivage-work/`, workflows/operations, raw integration-agent
conversations, local evidence/log dumps, credentials, and machine-specific runtime
paths. Use sanitized examples, not exported live configuration. Public limitation
summaries may cite upstream issues but must not import raw trial artifacts.

## GitHub Pages compatibility and scope boundary

Support the repository project prefix (for example `/lua-repl-mcp/`) as well as
a local preview. No root-relative assets/links that break project hosting.
Determine the real repository owner, default branch and Pages URL when deployment
is configured; do not hardcode an assumed remote or claim a live URL in advance.
No custom domain, analytics, third-party trackers, or additional service backend.

Saivage's task is limited to creating website content, static assets, and the
minimal local build/staging configuration needed to validate that content.
Pin verified build dependencies. Do not create publication/deployment workflows,
configure GitHub environments, change repository settings, push, or publish.
The instance has no publishing permissions, and obtaining those permissions is
not part of this task. Local content completion must not be blocked on GitHub
access or live deployment. A later operator-owned task can handle publication.
No credentials are needed to create or build the content.

## Acceptance

- Fresh environment installs pinned dependencies and runs a strict MkDocs build
  with warnings treated as failures; repeated builds have deterministic content
  apart from explicitly documented tool metadata.
- Links and downloaded schemas resolve at the project-prefix URL, including
  fragments and reference pages, without exposing excluded files.
- Browser smoke checks cover home, installation, manager API and embedding on
  desktop/mobile layouts, navigation, code blocks, and keyboard access.
- Code examples and defaults agree with current contracts; reuse the contract
  checker and add checks for website-specific examples and generated references.
- Artifact inspection proves only allowlisted content is published; scan for
  secret-bearing names, accidental local paths, and private conversation artifacts.
- Record commands, pinned versions, outcomes, and local artifact paths in
  `docs/validation/WEBSITE.md`. State that publication is out of scope and not
  performed. No live URL or GitHub deployment is an acceptance requirement.
