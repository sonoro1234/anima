cmake_minimum_required(VERSION 2.8.7)
project(horn)


find_package(OpenMP REQUIRED)

set(CMAKE_C_FLAGS ${CMAKE_C_FLAGS} "-std=c11 -Wall ${OpenMP_C_FLAGS}")
set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} "-Wvla -Wall ${OpenMP_CXX_FLAGS}")

include_directories(phs_3 . )


add_library(horn MODULE horn.c)

install(TARGETS horn RUNTIME DESTINATION ${LUAJIT_BIN}
					LIBRARY DESTINATION ${LUAJIT_BIN}
)
INSTALL(FILES horn.lua DESTINATION ${LUAJIT_BIN}/lua/IPOL)


