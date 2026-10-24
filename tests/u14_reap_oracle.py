"""Narrow regression for procfs identity disappearing between open and read."""
from unittest.mock import patch
import reap_oracle
for gone in (FileNotFoundError(2, 'gone'), ProcessLookupError(3, 'reaped')):
    with patch.object(reap_oracle.Path, 'read_text', side_effect=gone):
        assert reap_oracle.identity(123) is None
        assert reap_oracle.disappeared(123, ('start', 'S', 1))
with patch.object(reap_oracle.Path, 'read_text', side_effect=PermissionError(13, 'denied')):
    try:
        reap_oracle.identity(123)
    except PermissionError:
        pass
    else:
        raise AssertionError('permission errors must not become disappearance')
print('PASS procfs ENOENT/ESRCH disappearance; unrelated access error preserved')
