# Repair fatal/wait response arbitration

1. Preserve a fake-clock case with 1ms wait/hard deadlines, late processing and
   confirmed worker death; assert fatal status instead of running/terminated.
2. Define commitment and resolution transitions; preserve already-returned pending
   responses while delivering fatal outcomes to still-outstanding eligible callers.
3. Test both event orders, two waiters, cancellation suppression, cleanup fallback
   and stale generations; validate each output against the tool schema.
4. Run manager/live MCP regressions and integrate with F13 ownership changes.

Dependencies: F05 public shapes and F13 decision boundary. Importance 4/5,
transversality 3/5. Do not retain disposed sessions merely to hide response loss.
