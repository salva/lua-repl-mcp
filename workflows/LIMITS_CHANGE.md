# Operator-approved U7 capacity correction — 2026-10-17

The operator authorized more generous, coherent limits and continuation after
the U7 maximum legal request-ID/result counterexample. Updated SPEC §14.4 and
PLAN U7 use 64 MiB worker frames, 128 MiB complete responses, and 256 MiB buffered
client output. Input/value limits remain 16 MiB. Conservative capacity floors
now apply equally to defaults and overrides, with no default-fit exemption.

Checked inside the dedicated container using the current production codec,
protocol encoder, and connection limits with explicit new capacity overrides:

- Maximum legal request: 16,777,216 bytes.
- Escape-heavy encoded values: 16,777,216 bytes.
- Complete response: 67,109,058 bytes, returned as the original success payload.
- New response bound: 134,217,728 bytes; remaining headroom: 67,108,670 bytes.
- Conservative worker floor: 34,996,224 bytes, below 67,108,864.
- Conservative response floor: 122,814,464 bytes, below 134,217,728.
- Output budget includes the complete response plus newline.

This validates the corrected capacity choice with explicit overrides. It does
not claim the old implementation defaults or the full U7 acceptance suite have
already been updated. The owning planner must change those defaults, remove the
default-only fit exemption, update acceptance fixtures, and run affected tests.
Historical red evidence remains valid for the former limits.
