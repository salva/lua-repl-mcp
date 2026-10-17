# F01 analysis review

Required change: identify the actual defective float path, `codec.lua:79`'s `string.format('%.17g', v)`, rather than attributing this reproduction to `tostring`. The integer branch uses tostring separately. Preserve the reproduced distinction between tuple splitting and object normalization failure.

The host-ownership and historical-baggage analysis is otherwise sound.

VERDICT: CHANGES_REQUESTED
