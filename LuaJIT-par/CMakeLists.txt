cmake_minimum_required(VERSION 2.8.7)
project(libpar)


set(CMAKE_C_FLAGS ${CMAKE_C_FLAGS} "-std=c11 -Wall")
set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} "-Wvla -Wall")

include_directories(par)

add_library(shapes MODULE shapes.c)
add_library(msquares MODULE msquares.c)

install(TARGETS shapes msquares DESTINATION ${LUAJIT_BIN})
INSTALL(FILES par_shapes.lua par_msquares.lua DESTINATION ${LUAJIT_BIN}/lua)

