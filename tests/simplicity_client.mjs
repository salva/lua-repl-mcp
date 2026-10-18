// Local installed Saivage client-component qualification; no service/config edits.
// Requires current-qualification/rocks beneath SAIVAGE_CARD_WORK_ROOT.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {McpManager} from '/opt/saivage/dist/src/mcp/mcp-manager.js';
import {ProcessRunner} from '/opt/saivage/dist/src/runtime/process-runner.js';
import {ManagedProcessGroupRegistry} from '/opt/saivage/dist/src/runtime/managed-process-group-registry.js';
const w=process.env.SAIVAGE_CARD_WORK_ROOT+'/current-qualification', root=w+'/client-root';
fs.mkdirSync(root+'/.saivage',{recursive:true});
const rocks=w+'/rocks';
const cfg={transport:'stdio',command:rocks+'/bin/lua-repl-mcp',args:[],env:{LUA_PATH:rocks+'/share/lua/5.4/?.lua;'+rocks+'/share/lua/5.4/?/init.lua',LUA_CPATH:rocks+'/lib/lua/5.4/?.so'},autostart:false,disabled:false};
const registry=new ManagedProcessGroupRegistry();
const runner=new ProcessRunner(root,registry,{fatal(e){throw e;}});
let launched; const spawn=runner.spawnInteractive.bind(runner); runner.spawnInteractive=(spec)=>{launched=spawn(spec);return launched;};
const manager=new McpManager({configAuthority:{loadMcpServer:n=>n==='qualification'?cfg:undefined,loadMcpServers:()=>({qualification:cfg})},processRunner:runner,mcpProcessRootScope:registry.createContainerScope(registry.rootScope,'qualification'),eventLogger:{appendEventPrepared(e){console.log('EVENT',JSON.stringify(e));}}});
const keepalive=setInterval(()=>{},1000); let calls=[];
try {
 console.log('START',JSON.stringify(await manager.startServer('qualification')));
 const tools=manager.getServerTools('qualification'); fs.writeFileSync(w+'/actual-tools.json',JSON.stringify(tools,null,2));
 console.log('DISCOVERY',JSON.stringify(tools)); assert.equal(tools.length,5);
 async function call(name,args){const cap=manager.findToolCapability('qualification',name);assert(cap);const r=await manager.invokeTool('qualification',cap.bindingId,name,args);calls.push({name,args,result:r});console.log('RETURN',JSON.stringify(calls.at(-1)));const s=r.structuredContent;assert(s);assert.deepEqual(JSON.parse(r.content.find(x=>x.type==='text').text),s);assert.equal(r.isError,!!s.error);return s;}
 const created=await call('session_create',{});assert(created.session_id);let sid=created.session_id;
 let r=await call('session_execute',{session_id:sid,code:'n=40; function add(x) return n+x end; return add(2),nil,...',args:[{ok:true}],wait_timeout_ms:null});assert.deepEqual(r.values,[42,null,{ok:true}]);
 r=await call('session_execute',{code:'return n==nil,add==nil',wait_timeout_ms:null});assert.deepEqual(r.values,[true,true]);let independent=r.session_id;
 r=await call('session_execute',{session_id:sid,code:'os.execute("sleep 1"); return 81',wait_timeout_ms:0});assert.equal(r.status,'running');
 await call('session_list',{});
 r=await call('session_wait',{session_id:sid,wait_timeout_ms:1});assert.equal(r.status,'running');
 r=await call('session_wait',{session_id:sid,wait_timeout_ms:null});assert.deepEqual(r.values,[81]);
 r=await call('session_wait',{session_id:sid,wait_timeout_ms:0});assert.equal(r.error.code,'result_unavailable');
 r=await call('session_execute',{session_id:sid,code:'once=(once or 0)+1; return function() end',wait_timeout_ms:null});assert.equal(r.error.code,'result_serialization_error');assert(r.session_usable);
 r=await call('session_execute',{session_id:sid,code:'return once',wait_timeout_ms:null});assert.deepEqual(r.values,[1]);
 fs.rmSync(w+'/shell-ready',{force:true});
 r=await call('session_execute',{session_id:sid,code:'os.execute('+JSON.stringify('touch '+w+'/shell-ready; sleep 10')+');return 99',wait_timeout_ms:0});assert.equal(r.status,'running');
 const shellDeadline=Date.now()+3000;
 while(!fs.existsSync(w+'/shell-ready')){assert(Date.now()<shellDeadline,'shell startup barrier');await new Promise(resolve=>setTimeout(resolve,10));}
 console.log('PASS actual shell entered before active kill');
 r=await call('session_kill',{session_id:sid});assert.equal(r.process_exit_confirmed,true);assert.equal(r.session_usable,false);
 r=await call('session_wait',{session_id:sid,wait_timeout_ms:null});assert(r.error);assert.equal(r.session_usable,false);assert.equal(r.error.code,'unknown_session');
 r=await call('session_execute',{session_id:independent,code:'return 42',wait_timeout_ms:null});assert.deepEqual(r.values,[42]);
 await call('session_kill',{session_id:independent});
 console.log('PASS actual installed Saivage McpManager discovery/native returns/persistence/isolation/finite-wait/consumption/error-recovery/kill');
} finally {fs.writeFileSync(w+'/client-results.json',JSON.stringify(calls,null,2));if(launched && launched.process.exitCode===null){const exited=new Promise(resolve=>launched.process.once('exit',resolve));launched.process.stdin.end();await exited;console.log('PASS client graceful EOF leader exit',launched.process.exitCode);await new Promise(r=>setTimeout(r,100));}console.log('STOP',JSON.stringify(await manager.stopServer('qualification')));const status=manager.getStatus();console.log('STATUS',JSON.stringify(status));assert.equal(status[0].containmentFailed,false);assert.equal(status[0].processId,null);await manager.cleanupForApplicationStop();clearInterval(keepalive);}
