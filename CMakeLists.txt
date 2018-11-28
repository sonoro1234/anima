PROJECT(anima)
#to allow install from subdirectory
cmake_minimum_required(VERSION 3.13)

#if(MSVC) #to work as all the others
set(CMAKE_SHARED_LIBRARY_PREFIX "")
#endif(MSVC)

option(ANIMA_BUILD_LUAJIT "Build LuaJIT" ON)
option(ANIMA_BUILD_IM "Build im" ON)
option(ANIMA_BUILD_GLFW "Build LuaJIT-GLFW" ON)
option(ANIMA_BUILD_SDL "Build LuaJIT-SDL2" ON)
option(ANIMA_BUILD_IMGUI "Build LuaJIT-IMGUI" ON)

#im modules
if(ANIMA_BUILD_IM)
add_subdirectory(mirror-im)
endif(ANIMA_BUILD_IM)

#luajit project
if(ANIMA_BUILD_LUAJIT)
add_subdirectory(LuaJIT)
endif(ANIMA_BUILD_LUAJIT)


set(CMAKE_INSTALL_PREFIX "./install")

if(ANIMA_BUILD_GLFW)
add_subdirectory(LuaJIT-GLFW)
set(IMPL_GLFW ON CACHE INTERNAL "imgui with glfw")
endif(ANIMA_BUILD_GLFW)

if(ANIMA_BUILD_SDL)
add_subdirectory(LuaJIT-SDL2)
set(IMPL_SDL ON CACHE INTERNAL "imgui with sdl")
endif(ANIMA_BUILD_SDL)

if(ANIMA_BUILD_IMGUI)
if(NOT ANIMA_BUILD_GLFW AND NOT ANIMA_BUILD_SDL)
	message(FATAL_ERROR "SDL or GLFW needed for ImGui.")
endif(NOT ANIMA_BUILD_GLFW AND NOT ANIMA_BUILD_SDL)
set(IMPL_OPENGL2 ON CACHE INTERNAL "imgui for opengl2")
set(IMPL_OPENGL3 ON CACHE INTERNAL "imgui with opengl3")
add_subdirectory(LuaJIT-ImGui)
endif(ANIMA_BUILD_IMGUI)

#########install

install(DIRECTORY anima DESTINATION ${LUAJIT_BIN}/lua)
install(FILES luafilesystem/lfs_ffi.lua DESTINATION ${LUAJIT_BIN}/lua)


