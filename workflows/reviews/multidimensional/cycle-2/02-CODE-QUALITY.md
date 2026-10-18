# Cycle 2 — code correctness and simplicity

Fresh Astra `ses_eb21ded6effeOmOmVh2Vbx7jfC`, pin `a600754`.
Condensed receipt; findings require skeptical consolidation, not automatic fixes.
Read instructions/contracts/current plans, handwritten runtime and selected diffs
from701320b. Pure probes with **Lua5.4.8**; no native modules/worker processes,
services/credentials/live state, edits or commits. No runtime acceptance claim.

## C2-Q01 — unbounded generated error.path defeats recoverable result failure

**High; high encoding confidence, worker exit source-derived; new metadata-fit gap
related F03/F05, distinct from fixed diagnostic-message allocation.**
[codec.lua:143](../../../../lua_repl_mcp/codec.lua#L143)–144 constructs key pointer
before key encoding;84–86 attaches pointer to encoded-size failure;
[evaluator.lua:50](../../../../lua_repl_mcp/evaluator.lua#L50)–51 copies error.path;
[errors.lua:37](../../../../lua_repl_mcp/errors.lua#L37)–39 bounds message/traceback,
not path; [worker_main.lua:10](../../../../lua_repl_mcp/worker_main.lua#L10)–11,57–64
asserts private encoding success and exits on failure.

Observed pure probe with input_bytes256, values_bytes16, diagnostic_bytes49,
worker_bytes1049142 (exact legal coupled floor):
`return {[string.rep("x",1100000)]=true}` returns failed,
result_serialization_error/completed; path1100010 bytes, message49;
worker encoding fails encoded-size limit. Next pure evaluation succeeds, proving
evaluator healthy, not actual managed recovery. Managed worker exit consequence
is source-derived and would violate recoverable serialization failure (§13.4).

Smallest repair: optional oversized path omission or suitable containing-value
path while preserving code/completed/effects. Alternative budget pointer building
and select fitting ancestor inside codec; more work, not automatically necessary.
No public key/path restriction or larger capacities to cover unbounded metadata.

## C2-Q02 — creation rechecks canonical bytes after wire admission

**Medium; high pure-probe confidence; residual F03.**
[manager.lua:100](../../../../lua_repl_mcp/manager.lua#L100)–106 only grants admitted
original-request context to session_execute; other tools clone against I.
[codec.lua:286](../../../../lua_repl_mcp/codec.lua#L286)–294 charges tab six bytes
where wire escape costs two. [guardian.lua:221](../../../../lua_repl_mcp/guardian.lua#L221)–224
and [worker_supervisor.lua:39](../../../../lua_repl_mcp/worker_supervisor.lua#L39)–44
also revalidate creation, so manager-only fix insufficient.

Observed pure manager/inert backend: I256,224-byte session_create frame with60
JSON backslash-t cwd characters, decode and original token retained as transport
does. Returns invalid_arguments/encoded size limit. Path characters are valid
UTF-8; existence is later creation question, not second network-size admission.

Carry admitted distinction through creation boundaries, preserve fresh structural
copy and canonical limit for actual in-memory calls. Alternative reuse complete
original request for creation; choose fewer changes. No new provenance framework.

## C2-Q03 — undeclared effective-limit variables

**Medium overall; helper ambient dependency low; high reproduced confidence.**
New integration mistakes since701320b, partly duplicate C2-A04/D01.

- handler.lua57 `input_bytes=input_bytes` undeclared; configured frame23 differs
  from protocol decoder43 fallback16MiB. Observed memory adapter, input17MiB,
  ping preceded by16MiB whitespace: legal frame returns -32700 parse error.
  Pass effective local input bound; downstream context also needs fixing.
- [evaluator.lua:67](../../../../lua_repl_mcp/evaluator.lua#L67)–71 reads
  admitted_input_bytes, only a different function's parameter. Observed
  `_G.admitted_input_bytes=1; evaluator.from_json('{"code":"return 1"}')`
  gives invalid_arguments/input size limit. Remove stray field if helper retains
  default admission, or explicitly forward if truly needed. No sandbox allegation:
  normal host-name collision is accidental coupling. Local dataflow, not hardening.

## C2-Q04 — duplicate argument-depth traversal

**Low; source confidence high; simplify candidate, not measured latency defect.**
[contracts.lua:48](../../../../lua_repl_mcp/contracts.lua#L48) clone D+2 already
accounts tool object+tuple;56–65 walks arguments again for n>D. For accepted shapes
checks are equivalent, revisiting entries/paths/checkpoints without new rejection
coverage. Remove only after D/D+1 controls establish equivalence; alternative leave
while fixing real defects. No new depth framework; cleanup must not block delivery.

## Improvements and historical baggage

Protected unpack/entry witness, optional protected traceback, bounded retained
diagnostic cleaning with late-invalid scan, raw fresh copying, locale-local
numeric conversion, pure/native separation and one-time guardian transfer are
substantive fixes. Do not remove necessary safety because review introduced it.
Duplicate depth walk/undeclared names are repair-induced integration costs.
Repeated response encoding has no established new latency failure: possible
optimization, not redesign authority. Prioritize metadata fit, admitted semantics
and local bindings; traversal cleanup optional. Native timing/cleanup/installed/
full-suite acceptance not reviewed here.
