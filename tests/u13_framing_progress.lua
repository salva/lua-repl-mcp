local framing=require('lua_repl_mcp.framing')
local f=framing.new(2*1048576)
local start=os.clock()
for i=1,24 do assert(f:feed(string.rep('x',8192)));assert(not f:pop()) end
assert(f:feed('\nfirst\nlast'))
assert(f:pop()==string.rep('x',24*8192));assert(f:pop()=='first');assert(not f:pop())
assert(f:feed('\n'));assert(f:pop()=='last')
-- Bounds must still count the suffix after the last complete frame.
local bounded=framing.new(3)
assert(bounded:feed('a\nb\nxy'));assert(not bounded:feed('zz'))
assert(bounded:pop()=='a');assert(bounded:pop()=='b');assert(select(2,bounded:pop()))
print('MEASURE partial_frame_cpu_seconds',os.clock()-start)
assert(os.clock()-start<2,'newline-free prefix scan is unbounded')
print('PASS incomplete_complete_multiple_frame_suffix_overflow_progress')
