/* Test host: one host-owned state and thread; no product native dependency. */
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static lua_State *owner;
static pthread_t thread;
static FILE *handle;
static int api(lua_State *L) {
  if (L != owner || !pthread_equal(thread,pthread_self())) return luaL_error(L,"wrong host state/thread");
  lua_Integer n=luaL_checkinteger(L,1);
  if (fprintf(handle,"%lld\n",(long long)n)<0) return luaL_error(L,"handle lost");
  lua_pushinteger(L,n+100); return 1;
}
static int alive(lua_State *L) { lua_pushboolean(L, fputs("alive\n",handle)>=0); return 1; }
int main(int argc,char **argv) {
  if(argc!=2) return 2;
  owner=luaL_newstate(); if(!owner) return 3;
  thread=pthread_self(); handle=tmpfile(); if(!handle) return 4;
  luaL_openlibs(owner);
  lua_pushcfunction(owner,api); lua_setglobal(owner,"host_api");
  lua_pushcfunction(owner,alive); lua_setglobal(owner,"host_handle_alive");
  lua_pushinteger(owner,10); lua_setglobal(owner,"host_value");
  int e=luaL_dofile(owner,argv[1]);
  if(e) fprintf(stderr,"%s\n",lua_tostring(owner,-1));
  /* Only the parent selects final handle cleanup and interpreter shutdown. */
  fclose(handle); lua_close(owner); return e ? 1 : 0;
}
