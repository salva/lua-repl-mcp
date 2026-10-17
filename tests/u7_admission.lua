-- Affected-path coverage complementing the unchanged accepted reproducer.
local manager=require('lua_repl_mcp.manager')
local framing=require('lua_repl_mcp.framing')
local function backend()
 local b={clock=function() return 0 end,cwd='/',count=0}
 function b:allocate() self.count=self.count+1; return {state='starting'} end
 function b:abort(w) w.state='terminating' end
 function b:step() end
 function b:shutdown() return true end
 return b
end
for _,o in ipairs({{sessions=0},{ordinary=1.5},{control=7},{kill_reserve=7},{unknown=1}}) do
 assert(not pcall(manager.new,{supervisor=backend(),admission=o}))
end
local b=backend()
local m=manager.new{supervisor=b,admission={sessions=1,ordinary=1}}
local create=m:accept('session_create',{},'a')
assert(m:preview(m:accept('session_create',{},'b')).error.code=='limit_exceeded')
assert(b.count==1)
assert(m:cancel('a')); assert(m.slots.ordinary==0)
-- Cancellation releases request capacity but NOT a terminating worker's session.
local denied=m:accept('session_execute',{code=''},'c')
assert(m:preview(denied).error.code=='limit_exceeded' and b.count==1)
assert(m:commit(denied,function() return true end)); assert(m.slots.ordinary==0)
create.session.worker.state='dead'; m:refresh()
local replacement=m:accept('session_create',{},'d'); assert(b.count==2)
-- Control reserve stays independent from ordinary calls, including failed sends.
local controls={}
for i=1,24 do controls[i]=m:accept('session_list',{},'list'..i) end
assert(m.slots.control==24)
assert(m:preview(m:accept('session_list',{},'excess-list')).error.code=='limit_exceeded')
local kills={}
for i=1,8 do kills[i]=m:accept('session_kill',{session_id=replacement.session.id},'kill'..i) end
assert(m.slots.kill==8)
assert(m:preview(m:accept('session_kill',{session_id=replacement.session.id},'excess-kill')).error.code=='limit_exceeded')
assert(not m:commit(controls[1],function() return false end)); assert(m.slots.control==24)
assert(m:commit(controls[1],function() return true end)); assert(m.slots.control==23)
assert(m:cancel('kill1') and m.slots.kill==7)
assert(replacement.session.worker.state=='terminating')
m:disconnect()
print('PASS configured_admission_release_session_lifetime_and_kill_reserve')
-- Legal coalesced frames and handoff are preserved; only the overflow frame is
-- clipped. Fragmented overflow is sticky and never grows on subsequent feed.
local f=framing.new(4)
assert(f:feed('abcd\nx\n12')); assert(f:pop()=='abcd')
local messages,tail=f:handoff(); assert(messages[1]=='x' and tail=='12')
assert(not f:feed(string.rep('z',100)))
assert(f:pop()=='x'); assert(#f.buffer==5)
local _,err=f:pop(); assert(err)
local before=f.buffer; assert(not f:feed('more\n')); assert(f.buffer==before)
print('PASS fragmented_coalesced_handoff_and_sticky_overflow')
