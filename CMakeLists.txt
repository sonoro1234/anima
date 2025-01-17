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
######################################
option(LUAJIT_WINDOW_ONLY "Build only LuaJIT-Window" OFF)
option(ANIMA_BUILD_LUAJIT "Build LuaJIT" ON)
option(ANIMA_BUILD_IM "Build im" ON)
option(ANIMA_BUILD_GLFW "Build LuaJIT-GLFW" ON)
option(ANIMA_BUILD_SDL "Build LuaJIT-SDL2" ON)
option(ANIMA_BUILD_SDL3 "Build LuaJIT-SDL3" ON)
option(ANIMA_BUILD_IMGUI "Build LuaJIT-IMGUI" ON)
option(ANIMA_BUILD_FREETYPE "Build LuaJIT-freetype" ON)
option(ANIMA_BUILD_SNDFILE "Build LuaJIT-libsndfile" ON)
option(ANIMA_BUILD_RTAUDIO "Build LuaJIT-rtaudio" OFF)
option(ANIMA_BUILD_RTMIDI "Build LuaJIT-rtmidi" OFF)

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
if(ANIMA_BUILD_IM AND NOT LUAJIT_WINDOW_ONLY)
add_subdirectory(mirror-im)
endif(ANIMA_BUILD_IM AND NOT LUAJIT_WINDOW_ONLY)

#luajit project
if(ANIMA_BUILD_LUAJIT)
add_subdirectory(LuaJIT)
endif(ANIMA_BUILD_LUAJIT)

if(ANIMA_BUILD_SNDFILE)
add_subdirectory(luajit-libsndfile)
set(REAL_HAVE_GETTIMEOFDAY HAVE_GETTIMEOFDAY)
#message("LuaJIT-libsndfile HAVE_GETTIMEOFDAY " ${HAVE_GETTIMEOFDAY})
endif(ANIMA_BUILD_SNDFILE)

add_subdirectory(LuaJIT-GL)

#include(ExternalProject)
if(ANIMA_BUILD_GLFW)
	add_subdirectory(LuaJIT-GLFW)
	set(IMPL_GLFW ON CACHE INTERNAL "imgui with glfw")
else(ANIMA_BUILD_GLFW)
	set(IMPL_GLFW OFF CACHE INTERNAL "imgui with glfw")
endif(ANIMA_BUILD_GLFW)

if(ANIMA_BUILD_SDL)
	add_subdirectory(LuaJIT-SDL2)
	set(IMPL_SDL ON CACHE INTERNAL "imgui with sdl")
else(ANIMA_BUILD_SDL)
	set(IMPL_SDL OFF CACHE INTERNAL "imgui with sdl")
endif(ANIMA_BUILD_SDL)

if(ANIMA_BUILD_SDL3)
	add_subdirectory(LuaJIT-SDL3)
	set(IMPL_SDL3 ON CACHE INTERNAL "imgui with sdl3")
else(ANIMA_BUILD_SDL3)
	set(IMPL_SDL3 OFF CACHE INTERNAL "imgui with sdl3")
endif(ANIMA_BUILD_SDL3)

if(ANIMA_BUILD_FREETYPE)
	add_subdirectory(LuaJIT-freetype)
	set(IMGUI_FREETYPE ON CACHE INTERNAL "imgui with freetype")
	set(IMGUI_WCHAR32 ON CACHE INTERNAL "imgui with wchar32")
else(ANIMA_BUILD_SDL3)
	set(IMGUI_FREETYPE OFF CACHE INTERNAL "imgui with freetype")
endif(ANIMA_BUILD_FREETYPE)

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
	set(IMPL_EXTRAS ON CACHE INTERNAL "imgui extras")
	add_subdirectory(LuaJIT-ImGui)
endif(ANIMA_BUILD_IMGUI)

if(ANIMA_BUILD_RTAUDIO)
set(HAVE_GETTIMEOFDAY OFF)
add_subdirectory(LuaJIT-rtaudio)
#message("LuaJIT-rtaudio HAVE_GETTIMEOFDAY " ${HAVE_GETTIMEOFDAY})
endif(ANIMA_BUILD_RTAUDIO)

if(ANIMA_BUILD_RTMIDI)
add_subdirectory(LuaJIT-rtmidi)
endif(ANIMA_BUILD_RTMIDI)

add_subdirectory(luajit-async)

if(NOT LUAJIT_WINDOW_ONLY)
add_subdirectory(LuaJIT-par)
endif(NOT LUAJIT_WINDOW_ONLY)

if(WIN32)
	if(MSVC)
		set(LUA_LIBRARY ${CMAKE_BINARY_DIR}/LuaJIT/luajit-2.1/project_luajit/src/lua51.lib)
	else() #mingw
		set(LUA_LIBRARY ${CMAKE_BINARY_DIR}/LuaJIT/luajit-2.1/project_luajit/src/lua51.dll)
	endif()
	#set(LUA_LIBRARY ${CMAKE_BINARY_DIR}/LuaJIT/luajit-2.1/project_luajit/src/lua51.dll)
endif()
set(LUA_INCLUDE_DIR ${CMAKE_BINARY_DIR}/LuaJIT/luajit-2.1/project_luajit/src)

if(NOT LUAJIT_WINDOW_ONLY)
add_subdirectory(luanoise)
add_subdirectory(LuaJIT-IPOL)
endif(NOT LUAJIT_WINDOW_ONLY)
#########install

if(NOT LUAJIT_WINDOW_ONLY)
install(DIRECTORY anima DESTINATION ${LUAJIT_BIN}/lua)
install(DIRECTORY examples DESTINATION ${LUAJIT_BIN})
endif(NOT LUAJIT_WINDOW_ONLY)

install(FILES luafilesystem/lfs_ffi.lua luafilesystem/lfs.lua DESTINATION ${LUAJIT_BIN}/lua)
install(FILES ffi-reflect/reflect.lua DESTINATION ${LUAJIT_BIN}/lua)
install(DIRECTORY LuaJIT-ImGui/examples DESTINATION ${LUAJIT_BIN}/examples/LuaJIT-ImGui)
install(DIRECTORY LuaJIT-rtaudio/samples DESTINATION ${LUAJIT_BIN}/examples/LuaJIT-rtaudio)
install(DIRECTORY LuaJIT-rtmidi/examples DESTINATION ${LUAJIT_BIN}/examples/LuaJIT-rtmidi)
install(DIRECTORY LuaJIT-SDL2/test DESTINATION ${LUAJIT_BIN}/examples/LuaJIT-SDL2)
install(DIRECTORY LuaJIT-SDL3/test DESTINATION ${LUAJIT_BIN}/examples/LuaJIT-SDL3)
install(DIRECTORY luajit-async/tests DESTINATION ${LUAJIT_BIN}/examples/luajit-async)
install(DIRECTORY luajit-libsndfile/test DESTINATION ${LUAJIT_BIN}/examples/luajit-libsndfile)
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
    set( CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS ${Mingw_Path}/libwinpthread-1.dll ${Mingw_Path}/libgomp-1.dll ${libgcc} ${Mingw_Path}/libstdc++-6.dll )
endif( MINGW )
set(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP TRUE)
include (InstallRequiredSystemLibraries)
INSTALL(FILES ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS} DESTINATION ${LUAJIT_BIN})




