-- F02 policy reproduction: independent death is not ordered allocation release.
local M=require('lua_repl_mcp.manager')
local b={clock=function() return 0 end,cwd='/fixture',allocations=0}
function b:can_allocate() return self.allocations<2 end
function b:allocate() self.allocations=self.allocations+1; return {state='idle'} end
function b:abort(w) w.state='dead'; w.process_exit_confirmed=true end
function b:step() end
local m=M.new{supervisor=b,admission={sessions=2}}
local function take(r) return assert(m:commit(r,function() return true end)) end
local first=take(m:accept('session_create',{})).session_id
local other=take(m:accept('session_create',{})).session_id
assert(take(m:accept('session_kill',{session_id=first})).process_exit_confirmed)
-- Backend still owns allocation credit, as with a blocked release queue.
local r=m:accept('session_create',{})
local v=m:preview(r)
print('OBS F02 outstanding='..b.allocations..' public='..#m.order..' unrelated='..tostring(m.sessions[other]~=nil)..' error='..tostring(v.error and v.error.code))
assert(b.allocations==2 and v.error and v.error.code=='limit_exceeded','F02 replacement dispatched before ordered allocation release')

b.allocations=b.allocations-1 -- ordered release progresses
assert(take(m:accept('session_create',{})).session_id)
assert(b.allocations==2 and m.sessions[other])
print('PASS F02 rejection_before_dispatch_then_ordered_release_reuse')
