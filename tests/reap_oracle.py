"""Identity disappearance oracle (termination alone, including zombies, is insufficient)."""
from pathlib import Path
import time


def identity(pid):
    try:
        fields = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()
        return fields[19], fields[0], int(fields[1])
    except (FileNotFoundError, ProcessLookupError):
        # procfs can open stat, then report ESRCH if that identity is reaped
        # before read. Both observations mean that sampled identity is gone.
        return None


def disappeared(pid, original):
    current = identity(pid)
    return current is None or current[0] != original[0]


def wait_disappeared(pid, original, deadline):
    while not disappeared(pid, original):
        assert time.monotonic() < deadline, 'original worker identity still present (possibly unreaped)'
        time.sleep(.01)
