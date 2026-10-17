-- U7 red: policy boundaries without forking 65 workers or requiring native modules.
local manager=require('lua_repl_mcp.manager')
local framing=require('lua_repl_mcp.framing')
local null=require('lua_repl_mcp').null
local failures=0
local function check(ok,name,detail)
 print((ok and 'PASS ' or 'FAIL ')..name..' '..detail)
 if not ok then failures=failures+1 end
end
local function backend()
 local b={clock=function() return 0 end,cwd='/fixture',count=0}
 function b:allocate() self.count=self.count+1; return {state='starting',created_paths={}} end
 function b:step() end
 function b:execute(w) w.state='running'; return 1 end
 function b:abort(w) w.state='terminating' end
 function b:shutdown() return true end
 return b
end
-- All live states occupy a slot, independent of outstanding creation requests.
for _,state in ipairs({'starting','idle','running','terminating'}) do
 local b=backend(); local m=manager.new{supervisor=b}
 for i=1,64 do
  local r=m:accept('session_create',{},'create-'..i)
  check(r.session~=nil and b.count==i,'session_'..state..'_'..i,'allocations='..b.count)
  r.session.worker.state=state
  if i==63 or i==64 then
   check(#m.order==i,'session_inventory_'..state..'_'..i,'live='..#m.order)
  end
 end
 local r=m:accept('session_create',{},'excess')
 local v=m:preview(r)
 check(b.count==64 and v and v.error and v.error.code=='limit_exceeded',
  'session_'..state..'_65_rejected_before_allocate','allocations='..b.count..' live='..#m.order)
 m:disconnect()
end
local b=backend(); local m=manager.new{supervisor=b}
local cr=m:accept('session_create',{},'create')
cr.session.worker.state='idle'; assert(m:commit(cr,function() return true end))
local id=cr.session.id
local e=m:accept('session_execute',{session_id=id,code='',wait_timeout_ms=0},'execute')
assert(m:commit(e,function() return true end))
for i=1,256 do
 local r=m:accept('session_wait',{session_id=id,wait_timeout_ms=null},'wait-'..i)
 assert(not m:preview(r))
end
local n=0; for _ in pairs(m.requests) do n=n+1 end
check(n==256,'ordinary_at_256','outstanding='..n)
local excess=m:accept('session_wait',{session_id=id,wait_timeout_ms=null},'wait-257')
local v=m:preview(excess)
n=0; for _ in pairs(m.requests) do n=n+1 end
check(n==256 and v and v.error and v.error.code=='limit_exceeded',
 'ordinary_257_rejected','outstanding='..n)
local list=m:preview(m:accept('session_list',{},'list'))
check(list and #list.sessions==1,'list_at_ordinary_saturation','session remains visible')
check(m:cancel('wait-1') and cr.session.worker.state=='terminating',
 'cancellation_at_ordinary_saturation','bound worker terminated')
m:disconnect()
-- feed must not retain the full oversized frame before pop notices the bound.
for _,size in ipairs({15,16,17,4096}) do
 local f=framing.new(16); f:feed(string.rep('x',size))
 local frame,err=f:pop()
 check(size<=16 and not frame and not err or size>16 and err~=nil,
  'frame_detection_'..size,'retained='..#f.buffer)
 check(#f.buffer<=17,'frame_retention_'..size,'retained='..#f.buffer..' limit=16')
end
print('U7 red gaps='..failures)
os.exit(failures==0 and 0 or 1)
