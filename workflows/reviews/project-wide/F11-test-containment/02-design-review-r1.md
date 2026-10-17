# F11 design review

Required change: specify containment ownership for nested runners. Several Python wrappers create new sessions/process groups; killing an outer subprocess/group does not contain those groups if the wrapper is killed before its finally block. Select one containment owner per fixture tree and an outer-watchdog protocol that permits or performs child-group cleanup. Do not rely on the guardian under test to contain its own failure.

The explicit manifest is justified. Reuse a small runner/helper rather than adding another nested wrapper layer with the same hole.

VERDICT: CHANGES_REQUESTED
