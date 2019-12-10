cmake_minimum_required(VERSION 2.8.7)
project(brox)


find_package(OpenMP REQUIRED)

set(CMAKE_C_FLAGS ${CMAKE_C_FLAGS} "-std=c11 -Wall ${OpenMP_C_FLAGS}")
set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} "-Wvla -Wall ${OpenMP_CXX_FLAGS}")

include_directories(sms_optic_flow_2.0/spatial )


add_library(brox MODULE brox.cpp)

install(TARGETS brox RUNTIME DESTINATION ${LUAJIT_BIN}
					LIBRARY DESTINATION ${LUAJIT_BIN}
)
INSTALL(FILES brox.lua DESTINATION ${LUAJIT_BIN}/lua/IPOL)


