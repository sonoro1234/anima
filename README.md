# anima
my tools for making videos with opengl
watch them at:
https://vimeo.com/user67846254

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

# cloning

Remember to do a recursive cloning of the repo to pull submodules also.
    git clone --recurse-submodules https://github.com/sonoro1234/anima.git

# compiling

In Linux you will need to install opengl libraries before building.

Started a building CMake system only needing -DLUAJIT_BIN="path where you desire installation".
From a sibling folder to the repo:

    cmake -DLUAJIT_BIN="/home/user/anima" ../anima
    make install

CMake 3.13 is needed for installing git submodules. (If your system doesnt have it it can be downloaded from https://cmake.org/download/ and then used from a script that sets the PATH)

Some CMake option to allow-disable building are:

* ANIMA_BUILD_LUAJIT - Building of LuaJIT
* ANIMA_BUILD_IM - Building of im
* ANIMA_BUILD_GLFW - Building of GLFW
* ANIMA_BUILD_SDL - Building of SDL2
* ANIMA_BUILD_IMGUI - Building of ImGui (This needs ANIMA_BUILD_GLFW or ANIMA_BUILD_SDL)
* ANIMA_BUILD_SNDFILE - Building of libsndfile and libsamplerate
* ANIMA_BUILD_RTAUDIO - Building of LuaJIT-rtaudio (defaults to OFF)

# running

In windows use:
    luajit script_to_run
In linux use:
    ./anima_launcher script_to_run
