# Documentation authority correction — work evidence

This is maintainer/work documentation, not a website or user-guide input.

## Scope

SPEC §15 is authoritative for user-documentation deliverables, functional/user
perspective and content boundaries. Website design implements those requirements;
U11 plans and validates delivery; launch supplies autonomous scope; AGENTS points
contributors to those authorities. Root human/LLM entry guides are user content.
No website deployment or complete U11 implementation is claimed here.

## Independent critical review

Reviewer: OpenAI GPT-6 Astra (`openai/gpt-6-astra`), separate agent session
`ses_eb5a8235fffeD1fjH6hrYL69bp`, read-only, no delegated children.

1. Round 1: missing embedded installation recipe (medium); obsolete U11
   integration-status prerequisite (low). Added pure-Lua copying/path/adapter
   instructions and removed the prerequisite.
2. Round 2: ordinary file `read(n)` could block short MCP frames waiting to fill
   the handler's read count (medium). Changed the illustrative adapter to
   `read(1)` and documented the throughput tradeoff/read-some alternative.
3. Round 3: **no issues found within the scoped review**. All prior findings
   resolved; authority and requirements aligned. This is review evidence, not
   acceptance of future website content or every runtime lifecycle scenario.

## Validation

- `python3 tests/docs_consumer.py`: three LLM-guide JSON argument examples match
  input schemas; the documented copied-module/path/file-adapter recipe initializes,
  executes `return 42` and closes over live pipes while input remains open. Host
  runs outside the checkout with only the copied pure-Lua module set; asserts no
  manager/server/posix module imports. External five-second response/process
  watchdogs bound the observed operations. Run on host Lua 5.4.8.
- `python3 docs/check_contracts.py`: PASS, 14 standalone schemas, 7 official MCP
  Tools, 2 discovery results, 23 examples and 125 regression cases. This does not
  validate installed-manager examples.
- `git diff --check`: PASS.

Clean-installed manager commands/examples and the full website user journey
remain explicit U11 gates. Current checks do not claim those tests have run.
Planner notification/adoption must be confirmed through supported controls;
editing a tracked requirement file alone does not establish it.
