# Separate control progress from bulk payload delivery

Focused option: bounded interleaving within current framing, with priority control
turns and acknowledged payload references. One-level-up option: independent small
control/liveness and bulk-result channels, with incremental allocation/generation
events and explicit payload acknowledgements. Choose the simplest topology whose
worst-case control delay is bounded independently of aggregate result size; a
new channel is justified only if interleaving cannot establish that proof.
Do not replace guardian ownership, enlarge caps to mask starvation, or reduce
permitted payload/session counts. Coordinate outcome ordering with F13.
