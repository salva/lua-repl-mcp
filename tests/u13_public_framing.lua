local framing=require('lua_repl_mcp.framing')
local function measure(n)
 local block=string.rep(' ',65536); local f=framing.new(n)
 collectgarbage('collect'); collectgarbage('stop')
 local start=collectgarbage('count')
 for i=1,n//65536 do assert(f:feed(block)); assert(f:pop()==nil) end
 local bytes=collectgarbage('count')-start; collectgarbage('restart')
 print(('OBS public_incomplete bytes=%d allocation_KiB=%.3f'):format(n,bytes))
 return bytes
end
local a=measure(1048576); local b=measure(16777216)
assert(b<a*24,'public framing recopies whole retained prefix')
-- Handoff is nondestructive, complete frames precede sticky overflow.
local f=framing.new(4)
assert(f:feed('a\nbb\nc')); assert(f:feed('d'))
local messages,tail=f:handoff(); assert(table.concat(messages,',')=='a,bb' and tail=='cd')
assert(f:pop()=='a' and f:pop()=='bb' and f:pop()==nil)
assert(f:feed('ef')); assert(not f:feed('g\nignored\n'))
assert(select(2,f:pop())=='input frame limit exceeded')
assert(not f:feed('\n'))
f=framing.new(4); assert(not f:feed('\n12345\n'))
assert(f:pop()==''); assert(select(2,f:pop())=='input frame limit exceeded')
f=framing.new(4); assert(f:feed('1234')); assert(f:feed('\nx\ny\n'))
assert(f:pop()=='1234' and f:pop()=='x' and f:pop()=='y' and f:pop()==nil)
print('PASS public_framing_allocation_handoff_partial_exact_overflow_order')

-- Differential stream model: every split, empty frames, overflow after complete
-- frames, repeated pop and nondestructive handoff. No JSON assumptions.
for _,wire in ipairs({'','a','\n','a\nbb\nc','1234\nx\n','ab\n12345\nx','12345','\n\nxyz\n'}) do
 for split=0,#wire do
  local model=''; local overflow=false; local q=framing.new(4)
  for _,piece in ipairs({wire:sub(1,split),wire:sub(split+1)}) do
   local accepted=not overflow
   if accepted then
    local length=#(model:match('[^\n]*$'))
    for i=1,#piece do
     local ch=piece:sub(i,i); model=model..ch
     if ch=='\n' then length=0 else length=length+1 end
     if length>4 then overflow=true; accepted=false; break end
    end
   end
   assert(not not q:feed(piece)==accepted)
   local messages,tail=q:handoff()
   assert(table.concat(messages,'\n')..(#messages>0 and '\n' or '')..tail==model)
   assert(q.bytes==#model and q.buffer==model)
  end
  while true do
   local p=model:find('\n',1,true)
   local value,err=q:pop()
   if p then assert(value==model:sub(1,p-1)); model=model:sub(p+1)
   else assert(value==nil and (not overflow or err=='input frame limit exceeded')); break end
  end
 end
end
print('PASS public_framing_stream_model_all_splits')
