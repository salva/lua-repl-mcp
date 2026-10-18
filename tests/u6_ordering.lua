-- Exercise the owning supervisor receive/deadline/drain transitions with real
-- protocol validation and pipes, deterministic clock and no scheduled sleeps.
local S=require('lua_repl_mcp.worker_supervisor')
local x=require('lua_repl_mcp.worker_posix')
local p=require('lua_repl_mcp.worker_protocol')
local c=require('lua_repl_mcp.codec')
-- A frame read schedules bounded validation; recording occurs on a later turn.
local function validated(b,w)
 local turns=0
 while w.validation do
  turns=turns+1; assert(turns<100,'ordering validation watchdog')
  b:drain(w)
 end
end
for _,time in ipairs({.009,.010,.011}) do
 for _,event in ipairs({'complete_exit','exit_complete','complete_eof','partial_eof','partial_deadline'}) do
  local now=0; local b=S.new{clock=function() return now end}
  local read,write=assert(x.u.pipe()); x.nonblock(read)
  local w={state='running',allocation_generation=1,execution_generation=1,
   execution_deadline=.01,read_fd=read,pending='',buffer=''}
  b.workers={w}
  local frame=assert(p.encode(p.record('result',1,{execution_generation=1,result={status='completed',values=c.array({9})}})))
  now=time
  if event:find('partial') then x.u.write(write,frame:sub(1,-3)) else x.u.write(write,frame) end
  if event=='exit_complete' then
   -- wait reports exit first, then the same bounded drain primitive runs.
   w.reaped=true; b:drain(w)
  else b:step(0) end
  if event:find('eof') then x.u.close(write); write=nil; b:step(0) end
  if event=='partial_deadline' then now=.01; b:step(0) end
  validated(b,w)
  local wins=time<.01 and not event:find('partial')
  assert((w.result~=nil)==not not wins,event..' '..time)
  if w.read_fd then x.u.close(w.read_fd) end
  if write then x.u.close(write) end
 end
end
-- Receive after validation samples the clock, rather than a pre-decode timestamp.
do
 local now=0; local b=S.new{clock=function() return now end}
 local w={state='running',allocation_generation=1,execution_generation=1,execution_deadline=.01,pending='',buffer=''}
 local decode=p.decode
 p.decode=function(text) local v=decode(text); now=.01; return v end
 local r,wr=x.u.pipe(); x.nonblock(r); w.read_fd=r
 x.u.write(wr,assert(p.encode(p.record('result',1,{execution_generation=1,result={status='completed',values=c.array({1})}}))))
 b:drain(w); validated(b,w); assert(w.failure=='execution_timeout' and not w.result)
 x.u.close(wr); p.decode=decode
end
print('PASS supervisor_15_complete_partial_exit_eof_boundary_permutations_validation_time')
