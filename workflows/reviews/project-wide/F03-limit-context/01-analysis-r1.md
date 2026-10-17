# One effective limit contract

Configured input/depth/result allowances must describe actual behaviour through
all layers. Re-encoding decoded JSON to clone it changes escaped byte counts
and applies hidden 16MiB/depth128 defaults. Independent wrapping defaults can
fail after execution effects and produce an envelope without a result. These
defaults are accidental restrictions, not owner requirements. Preserve original
wire-byte accounting, JSON conversion safety and the approved capacity equations.
No fix may silently lower accepted capacities or weaken strict table conversion.
