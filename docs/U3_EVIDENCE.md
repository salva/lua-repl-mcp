# U3 executable POSIX qualification

## Result and exact environment

Seven capability groups pass on **Lua 5.4.6**, **luaposix 36.3-1**
(`posix for Lua 5.4 / luaposix 36.3`), **bit32 5.3.5.1-1**, Ubuntu **24.04.5
LTS**, Linux **7.0.0-22-generic x86_64**, glibc **2.39-0ubuntu8.9**, GCC
**13.3.0-6ubuntu2~24.04.1**, LuaRocks **3.8.0**, Python **3.12.3**.
No manager implementation or U4–U7 acceptance is claimed.

The baseline `231b36e` had no U3 spike/evidence and `require('posix')` failed.
Dependency setup succeeded without privilege in ignored `.luarocks`. The owning
repair is executable binding qualification, not a stub dependency declaration or
native imports added to the pure handler. Production modules are unchanged.

## Reproduction and packaging handoff

See `workflows/U3_SETUP.md` for complete reproducible installation and invocation.
The actual initial install command, from a purpose-named card work directory, was:

```sh
luarocks --lua-version=5.4 --tree=/work/lua-repl-mcp/.luarocks install luaposix 36.3-1
```

It installed bit32 5.3.5.1-1 transitively and compiled all native modules against
`/usr/include/lua5.4`. Both dependency versions are explicit in the setup recipe.
Downloaded `https://luarocks.org/luaposix-36.3-1.src.rock` SHA-256:
`e9201eed27907f2e516489d87535e77b23c40e40da20c7a629df116decb336e3`.
U9 packaging must pin `luaposix == 36.3-1` for the manager and retain the tested
bit32 version in its reproducible dependency setup. Pure handler installation
must remain usable without either native dependency. No rockspec is introduced
prematurely; installation/worker resolution outside a checkout remains U9.

```sh
eval "$(luarocks --lua-version=5.4 --tree=.luarocks path)"
python3 tests/u3_posix.py
```

Two consecutive final runs exit **0**, each reporting seven PASS groups. Parent
serviced poll plus a second child in **0.086 / 0.087 seconds** while the first
remained blocked. Initial partial write **65536 / 1048576 bytes**; buffer filled
at **65536**, all bytes drained and checked. Full final spike output:
`work:///cards/card-c-b-a/processes/proc-6740e6f118e1/stdout.log` (the later overly
broad regression command in this process failed as explained below).

## Named checks and binding/error branches

| `tests/u3_posix.lua` group | Observable assertions |
| --- | --- |
| `monotonic_poll_timeout` | CLOCK_MONOTONIC timespec fields; empty poll times out, elapsed lower/upper bound |
| `nonblocking_partial_io_eagain_dup_eof` | F_GETFL/F_SETFL preserve flags with O_NONBLOCK; empty read EAGAIN; short write then full-pipe write EAGAIN; dup keeps writer alive; exact byte drain/short read; last writer close produces EOF |
| `sigpipe_default_and_ignored_epipe` | default SIGPIPE actually kills forked child; wait reports signal; ignored SIGPIPE returns nil/message/EPIPE without killing parent |
| `exec_exact_and_path_search_cloexec_dup2_module_paths` | fork + absolute exec and execp PATH search; F_SETFD CLOEXEC removes sentinel; dup2 clears CLOEXEC on intended channel; exec child imports native posix and pure handler using inherited explicit paths; payload, EOF and exit 0 |
| `exec_failure_errno_and_error_channel_cleanup` | failed absolute exec returns nil/message/ENOENT without exiting; CLOEXEC error pipe remains open on failure, carries errno; explicit exit 127; EOF and reap |
| `eintr_read_and_poll_no_restart` | real SIGALRM interrupts blocking read and poll; signal handler installed with flags=0 (not SA_RESTART); nil/message/EINTR; successful read retry; signal count and handler restoration |
| `blocked_child_parent_responsive_sigkill_wnohang_reap_cleanup` | readiness barrier plus Linux wchan confirms kernel pipe_read; WNOHANG reports running; parent poll and second child progress; first remains running; SIGKILL; repeated WNOHANG until exact killed/SIGKILL status, then ECHILD; EPIPE proves no leaked reader |

Every reaped child is checked again for ECHILD. Every test-owned descriptor is
tracked, closed, and the final ownership tables must be empty. EOF tests detect
leaked writers; EPIPE after termination detects leaked readers. This establishes
fixture pipe-end cleanup, not a claim of constant RSS or arbitrary descendant
supervision. Local reap deadlines are 3 seconds; failure cleanup sends SIGKILL,
closes descriptors and polls reaping for 2 seconds per remaining child. The
Python driver bounds the complete suite to 20 seconds and kills the isolated
process group on completion or timeout. Readiness is explicit, not inferred from
a fixed sleep. SIGALRM tests intentionally take two seconds total.

## Portability and constraints for later units

The runtime operations exercised are POSIX primitives exposed by luaposix;
`signal(signum, handler, flags)` uses sigaction and flags=0 makes EINTR observable.
Use explicit errno classification: EAGAIN means retry on readiness, EINTR means
recompute deadlines/retry; read empty string means EOF. Partial writes require
an offset; poll is not permission for an unbounded blocking write. Use monotonic
time, never wall time, and wait(pid,WNOHANG) for confirmation, not kill success.
Ignore SIGPIPE at the manager boundary to receive EPIPE; do not change embedded
handler signal policy. Set CLOEXEC deliberately and close unused ends in both
fork branches. CLOEXEC alone does not close descriptors across fork.

**Linux-only fixture extension:** `/proc/<pid>/wchan` matching `pipe_read` proves
that the blocked-child test reached its kernel call. This is NOT a required
manager API or an undocumented portable POSIX baseline. Other systems need an
OS-specific observation fixture (or a bounded C instrumentation fixture) before
claiming equivalent blocked-call evidence. No BSD/macOS qualification is claimed.
Pipes were chosen; socketpair is not needed or qualified. No pipe2, pidfd,
/proc fd enumeration, epoll or other Linux runtime facility is assumed. No
missing binding required an extension; portable poll/signal/wait behavior still
needs qualification on each supported platform.

## Attempts and regression results

First spike attempt failed in the exec child: LuaRocks' path lacked the checkout
`?/init.lua`, so requiring the pure handler could not find `lua_repl_mcp`.
Fixed the owning launcher search-path construction to prepend explicit absolute
`?.lua` and `?/init.lua` for both parent and child. Native paths remain supplied
by LuaRocks; no runtime module fallback or global path modification was added.
The next run and both strengthened final runs passed. The strengthened fixture
checks exact drained bytes and /proc blocked-read observation.

An initial blanket `tests/u2*.lua` regression loop incorrectly executed
`u2_host.lua` standalone; that host requires client requests and failed its
expected-close assertion at line 19 on EOF. This was an invocation error, not
ignored acceptance evidence. Reran the explicit suites and the host through its
real client:

```sh
set -e
for t in tests/u1.lua tests/u1_diagnostic_notice.lua tests/u1_public_entrypoint.lua \
 tests/u1_review_invalid_key.lua tests/u2.lua tests/u2_handler_entrypoint.lua \
 tests/u2_review_argument_matrix.lua tests/u2_review_false_arguments.lua; do
 lua5.4 "$t"
done
python3 tests/u2_live.py
git diff --check
```

All exit **0**: 14 U1 groups, diagnostic matrix, public sentinel and pointer
regressions, nine U2 groups, entrypoint, argument matrices and real pipe host.
This run used default paths without the native-tree environment, preserving the
handler's native-independent acceptance. Complete output:
`work:///cards/card-c-b-a/processes/proc-315ed9be5c32/stdout.log`.
Schemas/contract files were unchanged; no new schema-only evidence is substituted
for these process tests. Independent review and later packaging gates are not
claimed by this local repair evidence.
