# Conditional traceback capture

Focused option: conditionally capture a callable traceback and use a safe bounded
fallback. One-level-up option: document required versus optional host primitives
and add a reduced-library embedding fixture. Choose both minimal capture and
explicit supported primitive list, not a pluggable diagnostic subsystem. Never
import POSIX modules to compensate for absent host libraries.
