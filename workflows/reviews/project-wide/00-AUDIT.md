# Independent whole-project audit receipt

Auditor: GPT-6 Astra (`openai/gpt-6-astra`), independent session
`ses_eb4b53042ffeUaVmZf9Or5kvgL`. Baseline: immutable detached
`8383c03e1d1b38fb33a0573f80aeecdf179673ee`. The auditor reported 13 actionable
findings, catalogued as F01–F13 in this directory. Not a clean-release verdict.

## Reported coverage

Inspected all runtime modules/entrypoints, public schema and discovery generation,
wire examples, required spec/design/plan, rockspec, public guides and builder,
test inventory/runners and principal process/boundary fixtures, and current versus
historical acceptance claims. No source/state/credential/service files changed.

Executed: 16 selected pure/core-policy tests on Lua 5.4.8 and 5.5.0; contract gate
(14 schemas, 7 tools, 23 examples, 125 regressions); semantic discovery comparison;
two deterministic strict MkDocs builds in a disposable copy (34 artifacts,
10 HTML pages, 286 local links/assets/fragments); consumer/example/deliverable
checks; and independent finding probes documented in inventory files. A saved
real-agent evidence parser accepted 40 native results: that is historical-evidence
validation, **not a fresh live-client run**.

Native POSIX/clean-install suites were not rerun: luaposix/LuaRocks unavailable
in the audit environment. Browser smoke was not rerun: Playwright unavailable.
These are coverage limits, not automatically product defects. The F02 full legal
aggregate-load latency scenario still needs real-process qualification; mocked
noncompletion establishes the ordering/deadline gap, not measured production
latency at every load.

## Historical baggage and evolutionary-bias conclusion

Retain owner mandates (pure blocking host handler, explicit results, no capture
or public task IDs, guardian spawn ownership, progressive TERM20/KILL10/retry1s,
user-doc boundary and autonomous no-publication scope), and proven identity,
single-consumer, partial-effect and strict-conversion safeguards. Exact resource
constants are normative current bounds, not universal truths; do not lower them
to hide defects. POSIX native version pins are bounded-release choices.

Hidden codec defaults, repeated full result snapshots, lockstep control routing,
ambiguous fixture discovery and duplicated incomplete watchdogs are accidental
implementation evolution. Simplify those boundaries proportionately rather than
rewrite the architecture or multiply review stages. F13's ordering authority
must be explicit, not justified solely by existing tests. No absolute claim of
exhaustiveness or freedom from evolutionary bias is made.
