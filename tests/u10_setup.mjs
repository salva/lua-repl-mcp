#!/usr/bin/env node
// Prepare operator-owned configuration in a fresh, supported-init project only.
// No provider/auth values are logged. Active project files are read-only inputs.
import fs from 'node:fs';
import path from 'node:path';
import YAML from '/opt/saivage/node_modules/yaml/dist/index.js';
const root=process.env.SAIVAGE_CARD_WORK_ROOT;
if(!root) throw Error('SAIVAGE_CARD_WORK_ROOT required');
const target=path.join(root,'u10-diagnosis/project');
const config=path.join(target,'.saivage/saivage.yaml');
if(fs.existsSync(path.join(target,'.saivage/locks/runtime.lock')))throw Error('target running; refuse configuration edits');
const active=YAML.parse(fs.readFileSync('.saivage/saivage.yaml','utf8'));
const c=YAML.parse(fs.readFileSync(config,'utf8'));
c.providers=active.providers;c.models=active.models;c.compaction=active.compaction;
c.server={host:'127.0.0.1',port:18081};
const rocks=path.join(root,'u9-clean-reproducer/rocks');
c.mcpServers={lua:{transport:'stdio',command:rocks+'/bin/lua-repl-mcp',args:[],env:{LUA_PATH:rocks+'/share/lua/5.4/?.lua;'+rocks+'/share/lua/5.4/?/init.lua',LUA_CPATH:rocks+'/lib/lua/5.4/?.so'},autostart:false,disabled:false}};
fs.writeFileSync(config,YAML.stringify(c));
fs.copyFileSync('.saivage/auth-profiles.json',path.join(target,'.saivage/auth-profiles.json'));
fs.chmodSync(path.join(target,'.saivage/auth-profiles.json'),0o600);
console.log('Prepared isolated loopback configuration and private mode-0600 credentials.');
