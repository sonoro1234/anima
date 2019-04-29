PROJECT(anima) # VERSION 1)

#to allow install from subdirectory
cmake_minimum_required(VERSION 3.13)

if(WIN32) #to mingw work as all the others
set(CMAKE_SHARED_LIBRARY_PREFIX "")
endif(WIN32)

############ set RPATH still not tested
#[[if (APPLE)
    set(CMAKE_INSTALL_RPATH "@executable_path/")
else()
    set(CMAKE_INSTALL_RPATH "$ORIGIN/")
endif()

set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)
]]

option(ANIMA_BUILD_LUAJIT "Build LuaJIT" ON)
option(ANIMA_BUILD_IM "Build im" ON)
option(ANIMA_BUILD_GLFW "Build LuaJIT-GLFW" ON)
option(ANIMA_BUILD_SDL "Build LuaJIT-SDL2" ON)
option(ANIMA_BUILD_IMGUI "Build LuaJIT-IMGUI" ON)
option(ANIMA_BUILD_SNDFILE "Build LuaJIT-libsndfile" ON)
option(ANIMA_BUILD_RTAUDIO "Build LuaJIT-rtaudio" OFF)

# This function is used to force a build on a dependant project at cmake configuration phase.
# 
function (build_external_project target source_dir argn) #FOLLOWING ARGUMENTS are the CMAKE_ARGS of ExternalProject_Add
message( "cmakeargs in are " ${argn})
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
    message( "---------------------------configuring " ${target} "------------------------------")
    execute_process(COMMAND ${CMAKE_COMMAND}  -G ${CMAKE_GENERATOR} -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} ..
        WORKING_DIRECTORY ${trigger_build_dir}/build
        )
    message( "---------------------------building " ${target} "------------------------------")
    execute_process(COMMAND ${CMAKE_COMMAND} --build .
        WORKING_DIRECTORY ${trigger_build_dir}/build
        )
    message( "---------------------------ended " ${target} "------------------------------")

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
add_subdirectory(luajit-libsndfile)
set(REAL_HAVE_GETTIMEOFDAY HAVE_GETTIMEOFDAY)
#message("LuaJIT-libsndfile HAVE_GETTIMEOFDAY " ${HAVE_GETTIMEOFDAY})
endif(ANIMA_BUILD_SNDFILE)


#include(ExternalProject)
if(ANIMA_BUILD_GLFW)
	add_subdirectory(LuaJIT-GLFW)
	set(IMPL_GLFW ON CACHE INTERNAL "imgui with glfw")
	#build_external_project(luajit_glfw ${CMAKE_SOURCE_DIR}/LuaJIT-GLFW -DLUAJIT_BIN=${LUAJIT_BIN})
endif(ANIMA_BUILD_GLFW)

if(ANIMA_BUILD_SDL)
	add_subdirectory(LuaJIT-SDL2)
	set(IMPL_SDL ON CACHE INTERNAL "imgui with sdl")
	#build_external_project(luajit_sdl ${CMAKE_SOURCE_DIR}/LuaJIT-SDL2 "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} -DLUAJIT_BIN=${LUAJIT_BIN}")
endif(ANIMA_BUILD_SDL)

if(ANIMA_BUILD_IMGUI)
	if(ANIMA_BUILD_GLFW)
		#set(GLFW_PATH  ${CMAKE_BINARY_DIR}/force_luajit_glfw/build/luajit_glfw-prefix/src/luajit_glfw-build/install)
	endif(ANIMA_BUILD_GLFW)
	if(ANIMA_BUILD_SDL)
		#set(SDL_PATH  ${CMAKE_BINARY_DIR}/force_luajit_sdl/build/luajit_sdl-prefix/src/luajit_sdl-build/install)
	endif(ANIMA_BUILD_SDL)
	if(NOT ANIMA_BUILD_GLFW AND NOT ANIMA_BUILD_SDL)
		message(FATAL_ERROR "SDL or GLFW needed for ImGui.")
	endif(NOT ANIMA_BUILD_GLFW AND NOT ANIMA_BUILD_SDL)
	set(IMPL_OPENGL2 ON CACHE INTERNAL "imgui for opengl2")
	set(IMPL_OPENGL3 ON CACHE INTERNAL "imgui with opengl3")
	add_subdirectory(LuaJIT-ImGui)
endif(ANIMA_BUILD_IMGUI)

if(ANIMA_BUILD_RTAUDIO)
set(HAVE_GETTIMEOFDAY OFF)
add_subdirectory(LuaJIT-rtaudio)
#message("LuaJIT-rtaudio HAVE_GETTIMEOFDAY " ${HAVE_GETTIMEOFDAY})
endif(ANIMA_BUILD_RTAUDIO)

add_subdirectory(luajit-async)


add_subdirectory(LuaJIT-par)

#########install

install(DIRECTORY anima DESTINATION ${LUAJIT_BIN}/lua)
install(FILES luafilesystem/lfs_ffi.lua DESTINATION ${LUAJIT_BIN}/lua)
install(DIRECTORY examples DESTINATION ${LUAJIT_BIN})
#####linux luajit launcher
if(UNIX)
install(FILES anima_launcher 
PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
DESTINATION ${LUAJIT_BIN})
endif(UNIX)
##runtime libraries
if( MINGW )
    message( STATUS "    Installing system-libraries: MinGW DLLs." )
    get_filename_component( Mingw_Path ${CMAKE_CXX_COMPILER} PATH )
	file(GLOB libgcc LIST_DIRECTORIES false ${Mingw_Path}/libgcc*.dll)
	#message("libgcc is " ${libgcc})
    set( CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS ${Mingw_Path}/libwinpthread-1.dll ${libgcc} ${Mingw_Path}/libstdc++-6.dll )
endif( MINGW )
set(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP TRUE)
include (InstallRequiredSystemLibraries)
INSTALL(FILES ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS} DESTINATION ${LUAJIT_BIN})




