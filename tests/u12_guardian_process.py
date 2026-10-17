"""Affected-path guardian regression using the preserved readiness/execution probe."""
from containment import enter
enter(420)
import concurrent.futures
import signal
from u12_lifecycle_red import case

if __name__ == '__main__':
    cases = [(signal.SIGINT, 'infinite'), (signal.SIGTERM, 'infinite'),
             (signal.SIGKILL, 'idle')]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(lambda args: case(*args), cases))
    raise SystemExit(0 if all(results) else 1)
