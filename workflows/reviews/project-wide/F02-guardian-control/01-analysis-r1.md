# Control progress independently of result volume

The owner requires bounded progressive cleanup and responsive admission/control.
A guardian snapshot can contain roughly a GiB of individually legal retained
results. Waiting for that entire batch before control delivery defeats reserved
public control capacity. Backdated termination and restarted startup deadlines
compound the failure. Lockstep full snapshots and repeated consumed-result relay
are implementation accidents, not safety requirements. Real-load latency needs
measurement; mocked deadline failure already warrants correction. Maintain safe
guardian child ownership and generation-bound outcomes while changing routing.
