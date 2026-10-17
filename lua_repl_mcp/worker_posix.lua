-- Native dependencies only occur beneath manager/worker entrypoints.
local M={u=require('posix.unistd'),f=require('posix.fcntl'),s=require('posix.signal'),
 w=require('posix.sys.wait'),p=require('posix.poll'),t=require('posix.time'),e=require('posix.errno')}
function M.now()
 local t=assert(M.t.clock_gettime(M.t.CLOCK_MONOTONIC)); return t.tv_sec+t.tv_nsec/1e9
end
function M.clo(fd,on)
 local flags=assert(M.f.fcntl(fd,M.f.F_GETFD))
 return assert(M.f.fcntl(fd,M.f.F_SETFD,on and (flags|M.f.FD_CLOEXEC) or (flags & ~M.f.FD_CLOEXEC)))
end
function M.nonblock(fd)
 return assert(M.f.fcntl(fd,M.f.F_SETFL,assert(M.f.fcntl(fd,M.f.F_GETFL))|M.f.O_NONBLOCK))
end
function M.retryable(e) return e==M.e.EAGAIN or e==M.e.EINTR end
function M.write_all(fd,text)
 local off=1
 while off<=#text do
  local n,msg,e=M.u.write(fd,text:sub(off,off+65535))
  if n and n>0 then off=off+n elseif e~=M.e.EINTR then return nil,msg end
 end
 return true
end
-- Portable close sweep: use the OS descriptor ceiling, not a guessed small cap.
function M.close_except(a,b,c)
 local n=assert(M.u.sysconf(M.u._SC_OPEN_MAX))
 for fd=3,n-1 do if fd~=a and fd~=b and fd~=c then M.u.close(fd) end end
end
return M
