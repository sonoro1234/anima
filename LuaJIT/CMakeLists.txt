PROJECT(LuaJIT)
#to allow install from subdirectory
cmake_minimum_required(VERSION 3.17)

include(ExternalProject)

#luajit project
set(ljpre ${CMAKE_CURRENT_BINARY_DIR}/luajit-2.1)
set(ljdir ${ljpre}/project_luajit)
set(ljsrc ${ljpre}/project_luajit/src)
#set(URLLUAJIT http://luajit.org/download/LuaJIT-2.0.1.tar.gz)
#set(URLLUAJIT https://github.com/LuaJIT/LuaJIT.git)
if(UNIX)
    ExternalProject_Add(project_luajit
      PREFIX ${ljpre}
      SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/LuaJIT
	  CONFIGURE_COMMAND "" #${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_SOURCE_DIR}/LuaJIT ${ljdir}
      BINARY_DIR ${ljdir}
      BUILD_COMMAND ${CMAKE_MAKE_PROGRAM} CCOPT="-DLUAJIT_ENABLE_LUA52COMPAT"
      INSTALL_COMMAND ""
    )
    set (ljname libluajit.a)
else(UNIX)
  if(MSVC)
    ExternalProject_Add(project_luajit
      PREFIX ${ljpre}
	  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/LuaJIT
	  CONFIGURE_COMMAND "" #${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_SOURCE_DIR}/LuaJIT ${ljdir}
      BINARY_DIR ${ljsrc}
      BUILD_COMMAND ${ljsrc}/msvcbuild.bat #dont know how to set DLUAJIT_ENABLE_LUA52COMPAT
      INSTALL_COMMAND ""
    )
    set (ljname lua51.lib)
  else(MSVC) #mingw
      set(DEBFLAGS "")
      if(CMAKE_BUILD_TYPE MATCHES Debug)
		message(STATUS "luajit debug build")
		set(DEBFLAGS " CCDEBUG= -g ")
	  endif()

      ExternalProject_Add(project_luajit
      PREFIX ${ljpre}
	  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/LuaJIT
	  CONFIGURE_COMMAND "" #${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_SOURCE_DIR}/LuaJIT ${ljdir}
      BINARY_DIR ${ljsrc}
      BUILD_COMMAND ${CMAKE_MAKE_PROGRAM} CCOPT="-DLUAJIT_ENABLE_LUA52COMPAT" ${DEBFLAGS}
      INSTALL_COMMAND ""
    )
		
  endif(MSVC)
    set (ljdllname lua51.dll)
endif(UNIX)

#generate .relver
execute_process(COMMAND git archive -o archivo.tar HEAD WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/LuaJIT)
#move sources to binary and extract
execute_process(COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/LuaJIT/archivo.tar ${ljdir})
execute_process(COMMAND ${CMAKE_COMMAND} -E tar x archivo.tar WORKING_DIRECTORY ${ljdir})
#delete archivo.tar
execute_process(COMMAND ${CMAKE_COMMAND} -E rm archivo.tar WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/LuaJIT)
#########install

if(UNIX)
install(FILES ${ljsrc}/luajit ${ljsrc}/libluajit.so 
  PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
  DESTINATION ${LUAJIT_BIN})
else(UNIX) #win
install(FILES ${ljsrc}/luajit.exe ${ljsrc}/lua51.dll DESTINATION ${LUAJIT_BIN})
endif(UNIX)
install(DIRECTORY ${ljsrc}/jit DESTINATION ${LUAJIT_BIN}/lua FILES_MATCHING PATTERN "*.lua")



