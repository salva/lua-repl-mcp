# Restore bounded guardian control

1. Preserve a deterministic noncompleting-report reproducer and add real legal
   aggregate-result/control latency coverage with external process containment.
2. Specify max control-service delay and bounded queues independently of payload
   length. Qualify interleaving versus separate channels and record the choice.
3. Carry original startup/disposal deadlines and identities across spawn/handoff;
   reject expired startup before dispatch. Begin disposal signalling promptly,
   preserving TERM20/KILL10/retry1s/30s-total policy without serial worker waits.
4. Release/acknowledge bulk payloads when public results are consumed or replaced;
   avoid re-encoding every payload on every snapshot. Keep retained memory bounded.
5. Verify saturated results plus kill/cancel/list, startup expiry, disconnect,
   manager-only death, backpressure, partial IPC and original-deadline handoff.
6. Re-run installed process suite and actual MCP-client integration after F13.

Dependencies: F03 limit context, F13 arbitration design. Importance 5/5,
transversality 5/5. Implement as a coherent ownership/transport batch; stop on
failed safety evidence rather than shipping a partial unbounded fallback.
