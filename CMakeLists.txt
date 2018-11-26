PROJECT(anima)
#to allow install from subdirectory
cmake_minimum_required(VERSION 3.13)
include(ExternalProject)

#luajit project
set(ljpre ${CMAKE_CURRENT_BINARY_DIR}/luajit-2.0.1)
set(ljsrc ${ljpre}/src/project_luajit/src)

if(UNIX)
    ExternalProject_Add(project_luajit
      URL http://luajit.org/download/LuaJIT-2.0.1.tar.gz
      PREFIX ${ljpre}
      CONFIGURE_COMMAND ""
      BUILD_IN_SOURCE 1
      BUILD_COMMAND make #-j8 ${cross_flag}
      INSTALL_COMMAND ""
      COMMAND ${CMAKE_COMMAND} -E copy ${ljsrc}/luajit ${ljpre}
      COMMAND ${CMAKE_COMMAND} -E copy ${ljsrc}/libluajit.a ${ljpre}
      COMMAND ${CMAKE_COMMAND} -E copy_directory ${ljsrc}/jit ${ljpre}/jit
    )
    set (ljname libluajit.a)
else(UNIX)
  if(MSVC)
    ExternalProject_Add(project_luajit
      URL http://luajit.org/download/LuaJIT-2.0.1.tar.gz
      PREFIX ${ljpre}
      CONFIGURE_COMMAND ""
      BINARY_DIR ${ljsrc}
      BUILD_COMMAND ${ljsrc}/msvcbuild.bat
      INSTALL_COMMAND ""
      COMMAND ${CMAKE_COMMAND} -E copy ${ljsrc}/luajit.exe ${ljpre}
      COMMAND ${CMAKE_COMMAND} -E copy ${ljsrc}/lua51.dll ${ljpre}
      COMMAND ${CMAKE_COMMAND} -E copy ${ljsrc}/lua51.lib ${ljpre}
      COMMAND ${CMAKE_COMMAND} -E copy_directory ${ljsrc}/jit ${ljpre}/lua/jit
    )
    set (ljname lua51.lib)
  else(MSVC) #mingw
      ExternalProject_Add(project_luajit
      URL http://luajit.org/download/LuaJIT-2.0.1.tar.gz
      PREFIX ${ljpre}
      CONFIGURE_COMMAND ""
      BINARY_DIR ${ljsrc}
      BUILD_COMMAND make
      INSTALL_COMMAND ""
    )
  endif(MSVC)
    set (ljdllname lua51.dll)
endif(UNIX)


set(CMAKE_INSTALL_PREFIX "./install")

add_subdirectory(LuaJIT-GLFW)
add_subdirectory(LuaJIT-SDL2)

set(IMPL_SDL ON CACHE INTERNAL "imgui with sdl")
set(IMPL_GLFW ON CACHE INTERNAL "imgui with glfw")
set(IMPL_OPENGL2 ON CACHE INTERNAL "imgui for opengl2")
set(IMPL_OPENGL3 ON CACHE INTERNAL "imgui with opengl3")
add_subdirectory(luajit-imgui)

#########install
##install(TARGETS glfw RUNTIME DESTINATION ${LUAJIT_BIN})
include (InstallRequiredSystemLibraries)
if(UNIX)
else(UNIX) #win
install(FILES ${ljsrc}/luajit.exe ${ljsrc}/lua51.dll DESTINATION ${LUAJIT_BIN})
install(DIRECTORY ${ljsrc}/jit DESTINATION ${LUAJIT_BIN}/lua/jit)
INSTALL(FILES ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS} DESTINATION ${LUAJIT_BIN})
endif(UNIX)


