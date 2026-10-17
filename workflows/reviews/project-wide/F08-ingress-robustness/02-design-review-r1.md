# F08 design review

Required changes:

1. Choose the exact duplicate-request wire policy now, including error code and response ID; do not leave 'choose a rejection' to implementation. The proposed invalid-request/null-ID policy can be selected explicitly while retaining the original request.
2. Define reservation release at committed response enqueue or suppressed cancellation, not merely terminal execution. Cover admission rejection, protocol rejection, failed encoding/enqueue, and disconnect, with one owner and no second competing registry.

The scope should remain correlation safety; no general compatibility dispatcher is needed.

VERDICT: CHANGES_REQUESTED
