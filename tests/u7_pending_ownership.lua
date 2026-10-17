-- Regression for admission ownership across transport submit/cancel/no tick.
local manager=require('lua_repl_mcp.manager')
local transport=require('lua_repl_mcp.client_transport')
local codec=require('lua_repl_mcp.codec')
local function backend()
 local b={clock=function() return 0 end,cwd='/',allocations=0}
 function b:allocate() self.allocations=self.allocations+1; return {state='starting',created_paths={}} end
 function b:step() end
 function b:abort(w) w.state='terminating' end
 function b:shutdown() return true end
 return b
end
local function new(options)
 local b=backend(); local m=manager.new{supervisor=b}
 local t=transport.new(m,{read=function() return nil,'again' end,
  write=function() return nil,'again' end},options)
 return t,m,b
end
local t,m,b=new{response_bytes=1024,output_bytes=2048}
for i=1,256 do t:submit(i,'session_create',{}) end
for i=1,24 do t:submit('list'..i,'session_list',{}) end
for i=1,8 do t:submit('kill'..i,'session_kill',{session_id=t.pending[1].request.session.id}) end
assert(#t.pending==288 and m.slots.kill==8 and m.slots.control==24)
local n=0
while not t.closed do
 n=n+1; assert(n<20)
 t:submit('rejected'..n,'session_create',{})
 if not t.closed then
  assert(#t.pending==288 and t.bytes>0 and t.bytes<=2048)
  local reply=assert(codec.decode(t.queue[#t.queue].text))
  assert(reply.id=='rejected'..n)
  assert(reply.result.structuredContent.error.code=='limit_exceeded')
 end
end
assert(m.closed and #t.pending==0 and t.bytes==0 and b.allocations==64)
assert(t.high_water<=2048)
print('PASS saturated_ordinary_control_kill_rejections_encoded_and_output_overflow_cleanup')
-- Repeated cancellation must not leave released request handles in pending.
t,m,b=new{}
for i=1,2048 do
 t:submit(i,'session_list',{})
 assert(t:cancel(i)); assert(m.slots.control==0)
 assert(#t.pending<=1)
end
assert(not t.closed)
t:submit('last','session_list',{})
assert(#t.pending==1 and m.slots.control==1)
-- Slotless rejection stays uncancellable: its ID must not target an old handle.
for i=1,23 do t:submit('hold'..i,'session_list',{}) end
t:submit('rejected','session_list',{})
assert(not t:cancel('rejected') and #t.pending==24 and t.bytes>0)
print('PASS cancellation_churn_reclaims_handles_without_tick_and_rejected_ID_inert')
