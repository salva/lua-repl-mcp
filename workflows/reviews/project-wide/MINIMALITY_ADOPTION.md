# Minimal-plan review and operational adoption

This is work evidence, excluded from user documentation and website staging.

## Source scope and review

The operator authorized Project Stop, dedicated-service stop, plan simplification,
iterative Astra review, service restart and normal Run. Stopped baseline:
`278a522`, including committed containment repairs. No runtime/test source was
reverted or modified by the plan editor. Current execution authority is
`99-METAPLAN.md`, with3 coherent batches; the expanded plan and all13 former
selected edition markers are explicitly superseded. SPEC owner guarantees are
preserved. PLAN U13 and LAUNCH use the smaller scope.

Fresh independent reviewer: GPT-6 Astra (`openai/gpt-6-astra`), session
`ses_eb479141affeYyX0CVJtcj34RJ`, separate from the original approval chain.
Initial minimality critique is retained in `FRESH_MINIMALITY_REVIEW.md`.

Minimal-plan review round1 found the technical direction sound and requested
two corrections: distinguish service restart from project Run, and point old
approval history to the superseded plan. Both were corrected. Round2:
**APPROVED — no actionable issues within the reviewed scope.** It confirms
proportionate mechanisms/gates, preserved byte/depth/control obligations and
clear supported adoption before Run. This is editorial approval, not runtime
qualification or a claim all13 defects are fixed.

## Stop and preservation

- Verified exact container `saivage-lua-repl-mcp`, IP10.0.3.18.
- Supported POST `/api/runtime/stop-project` returned stopped/contained:true;
  runtime became null. Active chain had been `card-f-a`.
- Dedicated `saivage.service` was stopped. Verified inactive/dead, MainPID0,
  empty control group and no remaining node/Lua/application descendants in the
  guest; lock directory had0 entries. Explicit Stop prevents on-failure restart.
- Unit inspected: user salva, cwd `/work/lua-repl-mcp`, Node entry
  `/opt/saivage/bin/saivage.js`, KillMode=control-group. No unit/runtime change.
- Complete stopped private copy under workspace
  `tmp/lua-repl-mcp-container-setup/minimality-adoption/stopped-project`, protected
  by its0700 parent. Includes credentials, state/history/work, source and hidden
  files. Credentials were never printed or added to Git.
- Inventory44828 entries:6918 directories,37799 regular files,111 symlinks;
  regular bytes2214454418. No FIFO/socket/unknown type required handling.
  All regular bytes, permissions/owners and symlink targets compared: PASS.
  No writable hardlink aliases to original files. No backup restoration or
  generated-state format changes are part of this adoption.

## Restart/adoption/resume status

Pending. Restart the exact dedicated service while execution stays stopped;
align accepted root/immediate-owner/stale descendant directions through supported
record/lifecycle tools; only then Run. Record actual returned child tools before
claiming successful resumption. Preserve existing effects and completed evidence.
