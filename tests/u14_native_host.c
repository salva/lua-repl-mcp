/* Independent managed-host fixture. Adapter owns FD3; session borrows it. */
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
static lua_State *owner;
static int read_part(lua_State *L) {
 char b[7]; ssize_t n; size_t cap=(size_t)luaL_checkinteger(L,1);
 if(cap>sizeof b) cap=sizeof b;
 do { n=read(3,b,cap); } while(n<0 && errno==EINTR);
 if(n<0) return luaL_error(L,"native read failed");
 if(n==0) { lua_pushnil(L); return 1; }
 lua_pushlstring(L,b,(size_t)n); return 1;
}
static int write_part(lua_State *L) {
 size_t size; const char *b=luaL_checklstring(L,1,&size); ssize_t n;
 if(size>11) size=11;
 do { n=write(3,b,size); } while(n<0 && errno==EINTR);
 if(n<=0) return luaL_error(L,"native write failed");
 lua_pushinteger(L,n); return 1;
}
static int flush(lua_State *L) { lua_pushboolean(L,1); return 1; }
static int api(lua_State *L) {
 if(L!=owner) return luaL_error(L,"wrong Lua state");
 lua_pushinteger(L,luaL_checkinteger(L,1)+100); return 1;
}
static int pid(lua_State *L) { lua_pushinteger(L,getpid()); return 1; }
static int block(lua_State *L) { (void)L; for(;;) pause(); return 0; }
static void global(const char *name,lua_CFunction f) {
 lua_pushcfunction(owner,f); lua_setglobal(owner,name);
}
int main(int argc,char **argv) {
 if(argc<2) return 2;
 int flags=fcntl(3,F_GETFD);
 if(flags<0 || (flags&FD_CLOEXEC) || fcntl(3,F_SETFD,flags|FD_CLOEXEC)<0) return 3;
 owner=luaL_newstate(); if(!owner) return 4;
 luaL_openlibs(owner);
 char cwd[4096]; if(!getcwd(cwd,sizeof cwd)) return 5;
 lua_pushstring(owner,cwd); lua_setglobal(owner,"host_cwd");
 global("host_api",api); global("host_pid",pid); global("host_block",block);
 global("native_read",read_part); global("native_write",write_part); global("native_flush",flush);
 lua_pushinteger(owner,10); lua_setglobal(owner,"host_value");
 lua_createtable(owner,argc-2,0);
 for(int i=2;i<argc;i++) { lua_pushstring(owner,argv[i]); lua_rawseti(owner,-2,i-1); }
 lua_setglobal(owner,"host_argv");
 int status=luaL_dofile(owner,argv[1]);
 if(status) fprintf(stderr,"%s\n",lua_tostring(owner,-1));
 if(!status && fcntl(3,F_GETFD)<0) status=1;
 close(3); lua_close(owner); return status ? 1 : 0;
}
