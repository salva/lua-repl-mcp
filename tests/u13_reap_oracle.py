"""Contained omitted-reap negative control plus installed manager-only crash."""
from containment import enter
enter(120)
import os
import signal
import time
from reap_oracle import identity, wait_disappeared

# Deliberately omit wait while retaining direct ownership. Never signal a
# guessed PID; the forked child exits itself. finally always reaps it.
pid = os.fork()
if pid == 0:
    os._exit(0)
try:
    original = identity(pid)
    assert original
    deadline = time.monotonic() + 2
    while identity(pid)[1] != 'Z':
        assert time.monotonic() < deadline
        time.sleep(.001)
    try:
        wait_disappeared(pid, original, time.monotonic() + .05)
    except AssertionError as error:
        assert 'still present' in str(error)
        print('PASS omitted_reap_negative_control_rejected_zombie', flush=True)
    else:
        raise AssertionError('omitted-reap mutant escaped oracle')
finally:
    os.waitpid(pid, 0)
wait_disappeared(pid, original, time.monotonic() + 1)
from u12_lifecycle_red import case
assert case(signal.SIGKILL, 'infinite'), 'installed guardian failed identity disappearance'
print('PASS manager_only_crash_worker_identity_disappears_before_external_cleanup', flush=True)
