-- U7 remaining admission seam: rejected calls must not build an unbounded
-- transport backlog outside the manager's bounded outstanding-request map.
local manager=require('lua_repl_mcp.manager')
local transport=require('lua_repl_mcp.client_transport')
local b={clock=function() return 0 end,cwd='/',allocations=0}
function b:allocate() self.allocations=self.allocations+1; return {state='starting',created_paths={}} end
function b:step() end
function b:abort(w) w.state='terminating' end
function b:shutdown() return true end
local m=manager.new{supervisor=b}
local t=transport.new(m,{read=function() return nil,'again' end,
 write=function() return nil,'again' end})
-- Each submitted frame is tiny and legal. The adapter can feed multiple decoded
-- frames without a transport tick; submit is the documented reusable U8 seam.
for i=1,256 do t:submit('create-'..i,'session_create',{}) end
local n=0; for _ in pairs(m.requests) do n=n+1 end
assert(n==256 and b.allocations==64)
local before=#t.pending
for i=1,4096 do t:submit('excess-'..i,'session_create',{}) end
local after=#t.pending
n=0; for _ in pairs(m.requests) do n=n+1 end
assert(n==256 and b.allocations==64,'manager admission regression')
print('MEASURE accepted_handles='..n..' pending_before='..before..
 ' pending_after='..after..' output_accounted='..t.bytes..
 ' output_bound='..t.output_bytes..' closed='..tostring(t.closed))
-- Rejected request handles, IDs, response objects and argument references are
-- retained despite no request slot or encoded-output byte reservation.
assert(t.closed or after<=288,
 'transport retains rejected flood outside ordinary/control/output bounds')
