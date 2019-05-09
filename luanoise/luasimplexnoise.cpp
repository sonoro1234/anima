extern "C" //noexternc
{
#include "lua.h"
#include "lauxlib.h"
#include <lualib.h>
LUALIB_API int luaopen_simplexnoise(lua_State *L);
}
#include "simplexnoise.h"
//octaves,persistence,scale,x,y
int lua_octave_noise_2d(lua_State *L)
{
	double val = octave_noise_2d(luaL_checknumber(L,1),luaL_checknumber(L,2),luaL_checknumber(L,3),luaL_checknumber(L,4),luaL_checknumber(L,5));
	lua_pushnumber(L,val);
	return 1;
}

int lua_octave_noise_3d(lua_State *L)
{
	double val = octave_noise_3d(luaL_checknumber(L,1),luaL_checknumber(L,2),luaL_checknumber(L,3),luaL_checknumber(L,4),luaL_checknumber(L,5),luaL_checknumber(L,6));
	lua_pushnumber(L,val);
	return 1;
}

int lua_octave_noise_4d(lua_State *L)
{
	double val = octave_noise_4d(luaL_checknumber(L,1),luaL_checknumber(L,2),luaL_checknumber(L,3),luaL_checknumber(L,4),luaL_checknumber(L,5),luaL_checknumber(L,6),luaL_checknumber(L,7));
	lua_pushnumber(L,val);
	return 1;
}

int lua_raw_noise_2d(lua_State *L)
{
	double val = raw_noise_2d(luaL_checknumber(L,1),luaL_checknumber(L,2));
	lua_pushnumber(L,val);
	return 1;
}

int lua_raw_noise_3d(lua_State *L)
{
	double val = raw_noise_3d(luaL_checknumber(L,1),luaL_checknumber(L,2),luaL_checknumber(L,3));
	lua_pushnumber(L,val);
	return 1;
}

int lua_raw_noise_4d(lua_State *L)
{
	double val = raw_noise_4d(luaL_checknumber(L,1),luaL_checknumber(L,2),luaL_checknumber(L,3),luaL_checknumber(L,4));
	lua_pushnumber(L,val);
	return 1;
}

int lua_raw_noise(lua_State *L)
{
  double val;
  int num_args = lua_gettop(L);
  if ((num_args < 2) || (num_args > 4))
    luaL_error(L, "invalid number of arguments: must be between 2 and 4.");

  switch(num_args)
  {
  case 2:  val = raw_noise_2d(luaL_checknumber(L,1),luaL_checknumber(L,2));  break;
  case 3:  val = raw_noise_3d(luaL_checknumber(L,1),luaL_checknumber(L,2),luaL_checknumber(L,3));  break;
  case 4:  val = raw_noise_4d(luaL_checknumber(L,1),luaL_checknumber(L,2),luaL_checknumber(L,3),luaL_checknumber(L,4));  break;
  }
	lua_pushnumber(L,val);
	return 1;
}

static const struct luaL_Reg thislib[] = {
  {"perlin_noise2d", lua_octave_noise_2d},
  {"perlin_noise3d", lua_octave_noise_3d},
  {"perlin_noise4d", lua_octave_noise_4d},
  {"raw_noise2d", lua_raw_noise_2d},
  {"raw_noise3d", lua_raw_noise_3d},
  {"raw_noise4d", lua_raw_noise_4d},
  {"raw_noise", lua_raw_noise},
  {NULL, NULL}
};
LUALIB_API int luaopen_simplexnoise (lua_State *L) {
  lua_newtable(L);
  luaL_register(L, NULL, thislib);
  return 1;
}