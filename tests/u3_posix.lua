-- Executable U3 binding qualification, not a manager implementation.
local u = require 'posix.unistd'
local f = require 'posix.fcntl'
local s = require 'posix.signal'
local w = require 'posix.sys.wait'
local p = require 'posix.poll'
local t = require 'posix.time'
local e = require 'posix.errno'
local function now()
  local v = assert(t.clock_gettime(t.CLOCK_MONOTONIC))
  return v.tv_sec + v.tv_nsec / 1e9
end
local function nb(fd)
  assert(f.fcntl(fd, f.F_SETFL, assert(f.fcntl(fd, f.F_GETFL)) | f.O_NONBLOCK) == 0)
end
local function clo(fd)
  assert(f.fcntl(fd, f.F_SETFD, assert(f.fcntl(fd, f.F_GETFD)) | f.FD_CLOEXEC) == 0)
end
if arg[1] == '--exec' then
  local out, gone, keep = tonumber(arg[2]), tonumber(arg[3]), tonumber(arg[4])
  local v, _, err = f.fcntl(gone, f.F_GETFD)
  assert(v == nil and err == e.EBADF, 'CLOEXEC descriptor survived')
  assert(f.fcntl(keep, f.F_GETFD) == 0, 'intended descriptor lost')
  assert(require('lua_repl_mcp.handler').serve)
  assert(require('posix').version:match('36%.3$'))
  assert(u.write(out, _VERSION .. ':native+pure:paths-ok') > 0)
  u._exit(0)
end
assert(_VERSION == 'Lua 5.4')
assert(require('posix').version:match('36%.3$'), 'qualification is pinned to 36.3')
local fds, kids = {}, {}
local function pipe()
  local a,b = assert(u.pipe())
  fds[a],fds[b] = true,true
  return a,b
end
local function close(fd)
  assert(u.close(fd) == 0); fds[fd] = nil
end
local function spawn(fn)
  local pid = assert(u.fork())
  if pid == 0 then
    local ok, why = xpcall(fn, debug.traceback)
    if not ok then io.stderr:write(why, '\n') end
    u._exit(ok and 0 or 111)
  end
  kids[pid] = true
  return pid
end
local function reap(pid, reason, status)
  local deadline = now() + 3
  while true do
    local got, why, code = w.wait(pid, w.WNOHANG)
    assert(got, why)
    if got ~= 0 then
      kids[pid] = nil
      assert(got == pid and why == reason and code == status,
        ('unexpected wait: %s %s %s'):format(got, why, code))
      local v, _, err = w.wait(pid, w.WNOHANG)
      assert(v == nil and err == e.ECHILD, 'child not consumed')
      return
    end
    assert(now() < deadline, 'reap deadline')
    assert(p.poll({}, 5) == 0)
  end
end
local function ready(fd, ms)
  local set = {[fd] = {events = {IN=true}}}
  local n = assert(p.poll(set, ms or 2000))
  assert(n == 1 and (set[fd].revents.IN or set[fd].revents.HUP), 'poll readiness')
end
local function eof(fd)
  ready(fd)
  assert(u.read(fd, 1) == '', 'leaked writer prevents EOF')
end
local count = 0
local function test(name, fn)
  fn(); count = count + 1; print('PASS ' .. name); io.stdout:flush()
end
local ok, why = xpcall(function()
  test('monotonic_poll_timeout', function()
    local a = now(); assert(p.poll({}, 25) == 0)
    local b = now(); assert(b >= a + .015 and b < a + 2)
  end)
  test('nonblocking_partial_io_eagain_dup_eof', function()
    local r,wr = pipe(); nb(r); nb(wr)
    local v,_,err = u.read(r, 1); assert(v == nil and err == e.EAGAIN)
    local payload = string.rep('x', 1048576)
    local n = assert(u.write(wr, payload)); assert(n > 0 and n < #payload)
    local total = n
    while true do
      local k,_,code = u.write(wr, payload)
      if not k then assert(code == e.EAGAIN); break end
      assert(k > 0); total = total + k; assert(total < 16*1024*1024)
    end
    local duplicate = assert(u.dup(wr)); fds[duplicate] = true
    close(wr)
    local read = 0
    while read < total do
      local chunk = assert(u.read(r, math.min(113, total-read)))
      assert(#chunk > 0 and #chunk <= 113 and chunk == string.rep('x', #chunk)); read = read + #chunk
    end
    local v2,_,err2 = u.read(r, 1); assert(v2 == nil and err2 == e.EAGAIN)
    assert(u.write(duplicate, 'tail') == 4)
    assert(u.read(r, 100) == 'tail') -- short read, not padded
    close(duplicate); eof(r); close(r)
    print(('  partial write=%d, filled=%d, exact drain=%d'):format(n,total,read))
  end)
  test('sigpipe_default_and_ignored_epipe', function()
    local pid = spawn(function()
      s.signal(s.SIGPIPE, s.SIG_DFL)
      local r,wr = u.pipe(); u.close(r); u.write(wr, 'x')
      error('default SIGPIPE did not kill child')
    end)
    reap(pid, 'killed', s.SIGPIPE)
    local old = assert(s.signal(s.SIGPIPE, s.SIG_IGN))
    local r,wr = pipe(); close(r)
    local v,_,err = u.write(wr, 'x'); assert(v == nil and err == e.EPIPE)
    close(wr); s.signal(s.SIGPIPE, old)
  end)
  test('exec_exact_and_path_search_cloexec_dup2_module_paths', function()
    for _, search in ipairs{false,true} do
      local r,wr = pipe(); local gone,other = pipe(); clo(gone); clo(other)
      local target = assert(u.dup(wr)); fds[target] = true
      clo(target)
      assert(u.dup2(wr,target) == target)
      assert(f.fcntl(target,f.F_GETFD) == 0, 'dup2 must clear CLOEXEC')
      local pid = spawn(function()
        u.close(r); u.close(wr)
        local args = {assert(os.getenv('U3_SCRIPT')), '--exec', tostring(target), tostring(gone), tostring(target)}
        local path = search and 'lua5.4' or assert(os.getenv('U3_LUA'))
        local v,msg = (search and u.execp or u.exec)(path,args)
        error(tostring(v)..':'..tostring(msg))
      end)
      close(wr); close(target); close(gone); close(other)
      ready(r); assert(u.read(r,1024) == 'Lua 5.4:native+pure:paths-ok')
      eof(r); reap(pid,'exited',0); close(r)
    end
  end)
  test('exec_failure_errno_and_error_channel_cleanup', function()
    local r,wr = pipe(); clo(wr)
    local pid = spawn(function()
      u.close(r)
      local v,_,err = u.exec('/definitely/absent/u3-lua', {})
      assert(v == nil and err == e.ENOENT)
      assert(u.write(wr, tostring(err)) > 0); u.close(wr)
      u._exit(127)
    end)
    close(wr); ready(r); assert(u.read(r,100) == tostring(e.ENOENT))
    eof(r); reap(pid,'exited',127); close(r)
  end)
  test('eintr_read_and_poll_no_restart', function()
    -- alarm is an actual signal, not an injected errno. No SA_RESTART.
    local seen = 0
    local old = assert(s.signal(s.SIGALRM, function() seen = seen + 1 end, 0))
    local r,wr = pipe()
    u.alarm(1)
    local v,_,err = u.read(r,1)
    assert(v == nil and err == e.EINTR and seen == 1)
    assert(u.write(wr,'retry') == 5); assert(u.read(r,5) == 'retry')
    u.alarm(1)
    local n,_,code = p.poll({[r]={events={IN=true}}}, 2500)
    assert(n == nil and code == e.EINTR and seen == 2)
    u.alarm(0); s.signal(s.SIGALRM,old)
    close(wr); eof(r); close(r)
  end)
  test('blocked_child_parent_responsive_sigkill_wnohang_reap_cleanup', function()
    local r,wr = pipe(); local ack,aw = pipe()
    local blocked = spawn(function()
      u.close(wr); u.close(ack)
      assert(u.write(aw,'ready') == 5); u.close(aw)
      -- Real blocking kernel read; parent retains writer with no data.
      assert(u.read(r,1)); error('blocked read unexpectedly returned')
    end)
    close(r); close(aw); ready(ack); assert(u.read(ack,5) == 'ready'); eof(ack); close(ack)
    local got,reason = w.wait(blocked,w.WNOHANG); assert(got == 0 and reason == 'running')
    -- Linux-only observation proves the readiness barrier progressed into read(2).
    local deadline = now()+2
    while true do
      local file = assert(io.open('/proc/'..blocked..'/wchan','r'))
      local channel = file:read('*a'); file:close()
      if channel:match('pipe_read') then break end
      assert(now()<deadline, 'child did not enter blocked pipe_read')
      p.poll({},5)
    end
    local start = now()
    assert(p.poll({},80) == 0)
    local rr,ww = pipe()
    local fast = spawn(function() u.close(rr); assert(u.write(ww,'responsive') == 10); u.close(ww) end)
    close(ww); ready(rr); assert(u.read(rr,100) == 'responsive'); eof(rr); close(rr)
    reap(fast,'exited',0)
    assert(w.wait(blocked,w.WNOHANG) == 0)
    local elapsed = now()-start; assert(elapsed < 2)
    assert(s.kill(blocked,s.SIGKILL) == 0); reap(blocked,'killed',s.SIGKILL)
    local old = assert(s.signal(s.SIGPIPE,s.SIG_IGN))
    local v,_,err = u.write(wr,'x'); assert(v == nil and err == e.EPIPE, 'leaked reader')
    s.signal(s.SIGPIPE,old); close(wr)
    print(('  parent serviced poll+second child in %.3fs while first remained blocked'):format(elapsed))
  end)
  assert(next(fds) == nil and next(kids) == nil, 'fixture ownership leak')
end, debug.traceback)
-- Always attempt disposal before reporting assertions. Outer watchdog is a second bound.
for pid in pairs(kids) do s.kill(pid,s.SIGKILL) end
for fd in pairs(fds) do u.close(fd) end
for pid in pairs(kids) do
  local deadline = now()+2
  repeat local got = w.wait(pid,w.WNOHANG); if got ~= 0 then break end; p.poll({},5) until now()>=deadline
end
if not ok then io.stderr:write(why,'\n'); os.exit(1) end
print(('PASS U3: %d named capability groups; no owned descriptors or unreaped children'):format(count))
