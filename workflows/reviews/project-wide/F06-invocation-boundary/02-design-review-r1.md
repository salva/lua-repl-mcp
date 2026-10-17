# F06 design review

Required changes:

1. Select the exact existing public code, stage, execution_state, and session usability for unpack/preparation failure, in agreement with F05/F07. 'Truthful pre-execution diagnostics' leaves the caller-visible contract undecided.
2. Define how user-chunk entry is detected. Moving unpack into xpcall alone catches the exception but can still label it started; the entry marker must be set only after argument preparation and immediately before invoking the chunk.
3. Keep traceback-generation failure from replacing the primary preparation/runtime error. State the protected fallback behavior in coordination with F09.

The protected-boundary alternative is appropriate; no public count capability is justified by current evidence.

VERDICT: CHANGES_REQUESTED
