-- Raw-copy validity/canonical-size controls and bounded diagnostic intermediates.
package.path='./?.lua;./?/init.lua'
package.cpath=''
local c=require('lua_repl_mcp.codec')
local errors=require('lua_repl_mcp.errors')
local e=require('lua_repl_mcp.evaluator')
local contracts=require('lua_repl_mcp.contracts')
local null=require('lua_repl_mcp').null
for _,depth in ipairs{1,128,512} do
 local value=7
 for _=1,depth do value={child=value} end
 local text=assert(c.encode({code='local v=...; while type(v)=="table" do v=v.child end; return v',args=c.array{value}},{max_depth=depth+2}))
 assert(e.from_json(text,{max_depth=depth}).values[1]==7)
end
local samples={null,false,1.5,'\0"\\😀',c.array{},c.object{},c.array{null,false,{},1.5}, {['a/b']={x=7}}}
for _,v in ipairs(samples) do
 local encoded=assert(c.encode(v))
 local copy,problem=c.clone(v,{max_bytes=#encoded}); assert(problem==nil)
 assert(c.encode(copy)==encoded)
 assert(not c.clone(v,{max_bytes=#encoded-1}))
end
local bad={{[1]='x',[3]='y'},{[1]='x',a=1},{[false]=1},{x=math.huge},{x=9007199254740992},{x='\255'}}
for _,v in ipairs(bad) do assert(not c.clone(v)) end
local shared={x=1}; local copy=assert(c.clone({a=shared,b=shared}))
assert(not rawequal(copy.a,copy.b))
for _,d in ipairs{1,2,128,512} do
 local v={}
 for _=1,d do v={x=v} end -- d+1 user containers
 local r=e.execute({code='error("must not run")',args=c.array{v}},{max_depth=d})
 assert(r.error and r.error.code=='invalid_arguments')
 local text=assert(c.encode({code='return 7',args=c.array{v}},{max_depth=d+3}))
 local a=contracts.from_json('repl_execute',text,{max_depth=d})
 assert(not a)
end
-- Compare constructor results with the previous full-clean algorithm without
-- allocating huge oracle strings. Independent scalar cleaning and UTF-8 prefix.
local function full(s)
 local out={}; local invalid=false; local i=1
 while i<=#s do
  local b=s:byte(i); local n=b<128 and 1 or b>=194 and b<=223 and 2 or b>=224 and b<=239 and 3 or b>=240 and b<=244 and 4 or 0
  local p=s:sub(i,i+n-1)
  if n>0 and #p==n and utf8.len(p)==1 then i=i+n
  else p=string.format('\\x%02X',b); invalid=true; i=i+1 end
  out[#out+1]=p
 end
 return table.concat(out),invalid
end
local function prefix(s,n)
 s=s:sub(1,n); while not utf8.len(s) do s=s:sub(1,-2) end; return s
end
local inputs={'','a',string.rep('a',80),string.rep('😀',20),'\255',string.rep('😀',20)..'\254',string.rep('a',90)..'\255'}
for _,message in ipairs(inputs) do for _,trace in ipairs(inputs) do for _,cap in ipairs{#errors.notice,80,100,200} do
 local m,a=full(message); local t,b=full(trace); local total=#m+#t
 local loss=a or b or total>cap
 if loss then
  m=prefix(m,cap-#errors.notice); t=prefix(t,cap-#errors.notice-#m)
 end
 local truncated=loss and #m+#t<total
 if loss then m=m..errors.notice end
 local r=errors.new('lua_runtime_error',message,'execution','started',{traceback=trace},cap)
 assert(r.message==m and (r.traceback or '')==t)
 assert(r.truncated==(truncated or nil))
 assert(r.invalid_bytes_escaped==((a or b) or nil))
end end end
-- Disable collection only inside this pure measurement. Inputs exist before
-- measuring; compare allocation retained by cleaning, not user allocation.
local function growth(n)
 local source=string.rep('a',n)..'\255'
 collectgarbage('collect'); collectgarbage('stop')
 local before=collectgarbage('count')
 local r=errors.new('lua_runtime_error',source,'execution','started',nil,80)
 local delta=collectgarbage('count')-before
 collectgarbage('restart')
 assert(r.invalid_bytes_escaped and r.truncated and #r.message<=80)
 return delta
end
local small,large=growth(10000),growth(1000000)
print('OBS diagnostic allocation KiB small='..small..' large='..large)
-- No allocator-specific quota. A 100x larger source must not retain a
-- proportional expanded out table/string when the output budget is unchanged.
assert(large<small*10)
assert(e.execute{code='return 42'}.values[1]==42)
print('PASS raw_copy_shapes_invalid_data_depth_and_196_diagnostic_comparisons_recovery')
