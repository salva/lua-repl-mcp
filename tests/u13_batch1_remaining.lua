local c=require('lua_repl_mcp.codec')
local e=require('lua_repl_mcp.evaluator')
local bad=0
local function check(name,fn) local ok,why=pcall(fn); print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why))); if not ok then bad=bad+1 end end
local original=os.setlocale(nil,'numeric')
local locales={}
for locale in (os.getenv('U13_LOCALES') or 'C en_DK.utf8'):gmatch('%S+') do locales[#locales+1]=locale end
for _,locale in ipairs(locales) do
 check('F01 exact numbers/count/range '..locale,function()
  assert(os.setlocale(locale,'numeric'))
  local before=os.setlocale(nil,'numeric')
  local setlocale=os.setlocale
  os.setlocale=function() error('codec must not change host locale') end
  local ok,why=pcall(function()
   assert(c.decode('1.5')==1.5 and c.decode('1.25e-2')==0.0125)
   assert(c.encode(1.5)=='1.5')
  end)
  os.setlocale=setlocale;assert(ok,why)
  assert(c.encode(1.5)=='1.5','float emission='..tostring(c.encode(1.5)))
  local obj=assert(c.decode('{"a":-1.25,"b":9007199254740991}'));assert(obj.a==-1.25 and obj.b==9007199254740991)
  assert(not c.decode('9007199254740992'))
  local r=e.execute{code='return 1.5,nil,-1.25'}
  assert(r.values and #r.values==3 and r.values[1]==1.5 and r.values[2]==require('lua_repl_mcp').null and r.values[3]==-1.25)
  assert(os.setlocale(nil,'numeric')==before)
 end)
end
assert(os.setlocale(original,'numeric'))
check('F06 oversized preparation protected/not_started/no witness/recovery',function()
 local args=c.array({});for i=1,1000000 do args[i]=0 end
 _G.batch1_witness=nil
 local ok,r=pcall(e.execute,{code='_G.batch1_witness=true;return 42',args=args})
 print('OBS protected='..tostring(ok)..' response='..tostring(r))
 assert(ok,'unprotected preparation raised: '..tostring(r))
 assert(r.error.code=='limit_exceeded' and r.error.stage=='execution' and r.error.execution_state=='not_started')
 assert(not _G.batch1_witness)
 assert(e.execute{code='return 42'}.values[1]==42)
 local ordinary=e.execute{code='error("ordinary")'};assert(ordinary.error.execution_state=='started')
end)
check('F07 bounded startup cause mapping survives cleanup',function()
 for _,cause in ipairs({'spawn_failed','startup_timeout','handshake_failed','cwd_setup_failed','stdio_setup_failed','transport_failed'}) do
  local backend={cwd='/fixture',clock=function() return 0 end}
  function backend:allocate() return {state='dead',failure=cause,startup_message=string.rep('diagnostic',100),reaped=true,created_paths={'/fixture/created'},files_complete=false} end
  local m=require('lua_repl_mcp.manager').new{supervisor=backend,limits={diagnostic_bytes=64}}
  local v=assert(m:preview(m:accept('session_create',{})))
  assert(v.error.reason==(cause=='transport_failed' and 'handshake_failed' or cause))
  assert(v.error.stage=='creation' and #v.error.message+#(v.error.traceback or '')<=64)
  assert(v.error.truncated and v.error.created_files[1]=='/fixture/created' and not v.error.created_files_complete)
 end
end)
print('TOTAL failures='..bad);os.exit(bad==0 and 0 or 1)
