cmake_minimum_required(VERSION 2.8.7)
project(libpar)

if(WIN32) #to mingw work as all the others
set(CMAKE_SHARED_LIBRARY_PREFIX "")
endif(WIN32)
# set(CMAKE_C_FLAGS ${CMAKE_C_FLAGS} "-std=c11 -Wall")
# set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} "-Wvla -Wall")
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS 1)
include_directories(par)

add_library(shapes SHARED shapes.c)
add_library(msquares SHARED msquares.c)
SET_TARGET_PROPERTIES(shapes PROPERTIES PREFIX "")
SET_TARGET_PROPERTIES(msquares PROPERTIES PREFIX "")

install(TARGETS shapes msquares RUNTIME DESTINATION ${LUAJIT_BIN}
					LIBRARY DESTINATION ${LUAJIT_BIN}
)
INSTALL(FILES par_shapes.lua par_msquares.lua DESTINATION ${LUAJIT_BIN}/lua)

