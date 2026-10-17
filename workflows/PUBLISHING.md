# Operator-owned GitHub publication

The operator explicitly authorized repository creation, pushing commits and
publishing GitHub Pages after the local-only U11 task. This is a separate host
operation, not publishing credentials or permission delegated to autonomous
executors. Their content/build validation scope remains unchanged.

- Repository: `https://github.com/salva/lua-repl-mcp` (public).
- Default branch: `master`; Pages source: `gh-pages`, root directory.
- Site URL: `https://salva.github.io/lua-repl-mcp/`.
- All source and generated-site commits must have author and committer
  `Salvador Fandiño <sfandino@yahoo.com>`.
- No release/tag, LuaRocks publication, license change or shared-runtime change
  is implied by pushing source or serving documentation.

## Publication procedure

Check every reachable commit's author/committer and scan tracked/history content
for secret-bearing files and likely token/private-key patterns without printing
values. This is a precaution, not a guarantee that a pattern scan finds all secrets.
Never publish ignored runtime/configuration, raw agent dumps or dependency trees.

Run the strict allowlisted website builder on a pinned source snapshot:

```sh
python3 docs/build_website.py --work-dir /absolute/workspace/tmp/website-build
```

Inspect its deterministic manifest, links and user/work boundary. Publish only
the resulting `site/` bytes, plus `.nojekyll`, to a clean `gh-pages` checkout
with the configured owner identity. Push the source branch without force; do
not silently replace an existing Pages history. Configure GitHub Pages for that
branch using supported GitHub API settings, then verify HTTP home, guide, assets
and exact schema download. Publication is not acceptance of known runtime defects.

Initial source/identity scan: 117 commits, all author/committer identities matched;
184 tracked paths and 861 historical objects checked, no tracked runtime/auth
files or selected token/private-key patterns found. Recheck before pushing final
changes. Deployment completion and immutable deployed source are recorded below
only after actual verification.

## Initial publication receipt

- Source publication: `f862576`, pushed to `origin/master` without force.
- Artifact commit: `c72db9a` on `gh-pages`, author/committer explicitly set to the
  requested owner. Only 34 audited generated artifacts plus `.nojekyll` included.
- GitHub Pages automatic branch build/deployment
  `https://github.com/salva/lua-repl-mcp/actions/runs/39062739621` succeeded.
  Pages API confirmed root `gh-pages` source and enforced HTTPS. Initial create
  returned already-enabled because GitHub auto-enabled the new Pages branch;
  existing correct settings were inspected rather than overwritten.
- Live HTTPS verification retrieved all 34 generated files and compared their
  bytes with the audited local artifact: PASS. This covers home, guides, assets,
  LLM guide and exact schema download. Schema SHA-256:
  `0329385383fde5180b78ec09057b5fd1ec2036891edd3a9db17ac246cc15a066`.
- The strict builder passed twice with deterministic manifests, 10 HTML pages,
  286 local links/assets/fragments and public-content boundary checks. Contract
  checker also passed. Host Python 3.14 / MkDocs 1.6.1.
- GitHub-managed legacy Pages workflow emitted Node20-action deprecation and
  upcoming runner-image notices; deployment succeeded. No project deployment
  workflow or automation publication credentials were added.
- Public home and README explicitly identify a development candidate with known
  correctness/lifecycle issues; publication is not a stable release announcement.
