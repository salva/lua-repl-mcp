"""Complete newline-frame deadline; readiness alone never proves completion."""
import os
import select
import time


def frame(stream, timeout=5, maximum=2*1024*1024):
    deadline = time.monotonic() + timeout
    data = bytearray()
    # Read one byte so following buffered frames remain owned by the caller.
    while not data.endswith(b'\n'):
        remaining = deadline - time.monotonic()
        assert remaining > 0 and select.select([stream], [], [], remaining)[0], 'complete-frame deadline'
        chunk = os.read(stream.fileno(), 1)
        assert chunk, 'EOF before complete frame'
        data.extend(chunk)
        assert len(data) <= maximum, 'frame size limit'
    assert time.monotonic() < deadline, 'complete-frame deadline'
    return data
