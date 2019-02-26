PROJECT(LuaJIT)
#to allow install from subdirectory
cmake_minimum_required(VERSION 3.13)

include(ExternalProject)

#luajit project
set(ljpre ${CMAKE_CURRENT_BINARY_DIR}/luajit-2.0.1)
set(ljsrc ${ljpre}/src/project_luajit/src)
#set(URLLUAJIT http://luajit.org/download/LuaJIT-2.0.1.tar.gz)
set(URLLUAJIT https://github.com/LuaJIT/LuaJIT.git)
if(UNIX)
    ExternalProject_Add(project_luajit
      #URL ${URLLUAJIT}
	  GIT_REPOSITORY ${URLLUAJIT}
	  GIT_TAG v2.1
      PREFIX ${ljpre}
      CONFIGURE_COMMAND ""
      BUILD_IN_SOURCE 1
      BUILD_COMMAND make #-j8 ${cross_flag}
      INSTALL_COMMAND ""
      # COMMAND ${CMAKE_COMMAND} -E copy ${ljsrc}/luajit ${ljpre}
      # COMMAND ${CMAKE_COMMAND} -E copy ${ljsrc}/libluajit.a ${ljpre}
      # COMMAND ${CMAKE_COMMAND} -E copy_directory ${ljsrc}/jit ${ljpre}/jit
    )
    set (ljname libluajit.a)
else(UNIX)
  if(MSVC)
    ExternalProject_Add(project_luajit
      #URL ${URLLUAJIT}
	  GIT_REPOSITORY ${URLLUAJIT}
	  GIT_TAG v2.1
      PREFIX ${ljpre}
      CONFIGURE_COMMAND ""
      BINARY_DIR ${ljsrc}
      BUILD_COMMAND ${ljsrc}/msvcbuild.bat
      INSTALL_COMMAND ""
    )
    set (ljname lua51.lib)
  else(MSVC) #mingw
      ExternalProject_Add(project_luajit
      #URL ${URLLUAJIT}
	  GIT_REPOSITORY ${URLLUAJIT}
	  GIT_TAG v2.1
      PREFIX ${ljpre}
      CONFIGURE_COMMAND ""
      BINARY_DIR ${ljsrc}
      BUILD_COMMAND ${MAKE}
      INSTALL_COMMAND ""
    )
  endif(MSVC)
    set (ljdllname lua51.dll)
endif(UNIX)


#########install

if(UNIX)
install(FILES ${ljsrc}/luajit ${ljsrc}/lua51.so DESTINATION ${LUAJIT_BIN})
else(UNIX) #win
install(FILES ${ljsrc}/luajit.exe ${ljsrc}/lua51.dll DESTINATION ${LUAJIT_BIN})
endif(UNIX)
install(DIRECTORY ${ljsrc}/jit DESTINATION ${LUAJIT_BIN}/lua/jit)



