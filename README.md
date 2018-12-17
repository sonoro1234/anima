# anima
my tools for making videos with opengl

anima folder should be in lua folder and then

```lua
--this loads some globals
require"anima"
--create a 1200x800 canvas without SDL (with GLFW)
local GL = GLcanvas{H=800,aspect=1.5,SDL=false}

function GL.init()
  --init gl stuff here
end

function GL.imgui()
  --run imgui code here
end

function GL.draw(t,w,h)
  --do gl work here
end

GL:start()
```
# compiling

Started a building CMake system only needing -DLUAJIT_BIN="path where you desire installation".

Most doubtful is LuaJIT building.(You can disable it with -DANIMA_BUILD_LUAJIT=no)

Some CMake option to allow-disable building are:

* ANIMA_BUILD_LUAJIT - Building of LuaJIT
* ANIMA_BUILD_IM - Building of im
* ANIMA_BUILD_GLFW - Building of GLFW
* ANIMA_BUILD_SDL - Building of SDL2
* ANIMA_BUILD_IMGUI - Building of ImGui (This needs ANIMA_BUILD_GLFW or ANIMA_BUILD_SDL)
* ANIMA_BUILD_SNDFILE - Building of libsndfile and libsamplerate
