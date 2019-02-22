PROJECT(anima)
#to allow install from subdirectory
cmake_minimum_required(VERSION 3.13)

#if(MSVC) #to work as all the others
set(CMAKE_SHARED_LIBRARY_PREFIX "")
#endif(MSVC)

option(ANIMA_BUILD_LUAJIT "Build LuaJIT" OFF)
option(ANIMA_BUILD_IM "Build im" OFF)
option(ANIMA_BUILD_GLFW "Build LuaJIT-GLFW" ON)
option(ANIMA_BUILD_SDL "Build LuaJIT-SDL2" ON)
option(ANIMA_BUILD_IMGUI "Build LuaJIT-IMGUI" ON)
option(ANIMA_BUILD_SNDFILE "Build LuaJIT-libsndfile" ON)
option(ANIMA_BUILD_RTAUDIO "Build LuaJIT-rtaudio" ON)

# This function is used to force a build on a dependant project at cmake configuration phase.
# 
function (build_external_project target source_dir argn) #FOLLOWING ARGUMENTS are the CMAKE_ARGS of ExternalProject_Add

    set(trigger_build_dir ${CMAKE_BINARY_DIR}/force_${target})

    #mktemp dir in build tree
    file(MAKE_DIRECTORY ${trigger_build_dir} ${trigger_build_dir}/build)

    #generate false dependency project
    set(CMAKE_LIST_CONTENT "
        cmake_minimum_required(VERSION 3.13)

        include(ExternalProject)
        ExternalProject_add(${target}
			SOURCE_DIR ${source_dir}
            CMAKE_ARGS ${argn}
            #INSTALL_COMMAND \"\"
            )

        add_custom_target(trigger_${target})
        add_dependencies(trigger_${target} ${target})
    ")

    file(WRITE ${trigger_build_dir}/CMakeLists.txt "${CMAKE_LIST_CONTENT}")

    execute_process(COMMAND ${CMAKE_COMMAND}  -G ${CMAKE_GENERATOR} ..
        WORKING_DIRECTORY ${trigger_build_dir}/build
        )
    execute_process(COMMAND ${CMAKE_COMMAND} --build .
        WORKING_DIRECTORY ${trigger_build_dir}/build
        )

endfunction()



#im modules
if(ANIMA_BUILD_IM)
add_subdirectory(mirror-im)
endif(ANIMA_BUILD_IM)

#luajit project
if(ANIMA_BUILD_LUAJIT)
add_subdirectory(LuaJIT)
endif(ANIMA_BUILD_LUAJIT)

if(ANIMA_BUILD_SNDFILE)
add_subdirectory(LuaJIT-libsndfile)
endif(ANIMA_BUILD_SNDFILE)


#include(ExternalProject)
if(ANIMA_BUILD_GLFW)
	#add_subdirectory(LuaJIT-GLFW)
	set(IMPL_GLFW ON CACHE INTERNAL "imgui with glfw")
	build_external_project(luajit_glfw ${CMAKE_SOURCE_DIR}/LuaJIT-GLFW -DLUAJIT_BIN=${LUAJIT_BIN})
endif(ANIMA_BUILD_GLFW)

if(ANIMA_BUILD_SDL)
	#add_subdirectory(LuaJIT-SDL2)
	set(IMPL_SDL ON CACHE INTERNAL "imgui with sdl")
	build_external_project(luajit_sdl ${CMAKE_SOURCE_DIR}/LuaJIT-SDL2 -DLUAJIT_BIN=${LUAJIT_BIN})
endif(ANIMA_BUILD_SDL)

if(ANIMA_BUILD_IMGUI)
	if(ANIMA_BUILD_GLFW)
		set(GLFW_PATH  ${CMAKE_BINARY_DIR}/force_luajit_glfw/build/luajit_glfw-prefix/src/luajit_glfw-build/install)
	endif(ANIMA_BUILD_GLFW)
	if(ANIMA_BUILD_SDL)
		set(SDL_PATH  ${CMAKE_BINARY_DIR}/force_luajit_sdl/build/luajit_sdl-prefix/src/luajit_sdl-build/install)
	endif(ANIMA_BUILD_SDL)
	if(NOT ANIMA_BUILD_GLFW AND NOT ANIMA_BUILD_SDL)
		message(FATAL_ERROR "SDL or GLFW needed for ImGui.")
	endif(NOT ANIMA_BUILD_GLFW AND NOT ANIMA_BUILD_SDL)
	set(IMPL_OPENGL2 ON CACHE INTERNAL "imgui for opengl2")
	set(IMPL_OPENGL3 ON CACHE INTERNAL "imgui with opengl3")
	add_subdirectory(LuaJIT-ImGui)
endif(ANIMA_BUILD_IMGUI)

if(ANIMA_BUILD_RTAUDIO)
add_subdirectory(LuaJIT-rtaudio)
endif(ANIMA_BUILD_RTAUDIO)

add_subdirectory(luajit-async)
#########install

install(DIRECTORY anima DESTINATION ${LUAJIT_BIN}/lua)
install(FILES luafilesystem/lfs_ffi.lua DESTINATION ${LUAJIT_BIN}/lua)




