cmake_minimum_required(VERSION 2.8.7)
project(tvl1)

find_package(OpenMP REQUIRED)

if(MSVC)
		#set(CMAKE_C_FLAGS ${CMAKE_C_FLAGS} /std:c17)#" ${OpenMP_C_FLAGS}")
		set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} "/std:c++17")#" ${OpenMP_C_FLAGS}")
else() 
		set(CMAKE_C_FLAGS ${CMAKE_C_FLAGS} "-std=c11 -Wall ${OpenMP_C_FLAGS}")
		set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} "-Wvla -Wall ${OpenMP_CXX_FLAGS}")
endif()



message(STATUS "openmp flags" ${OpenMP_C_FLAGS} ${OpenMP_CXX_FLAGS})

include_directories(tvl1flow_3 . )


add_library(tvl1 MODULE tvl1.c)

install(TARGETS tvl1 RUNTIME DESTINATION ${LUAJIT_BIN}
					LIBRARY DESTINATION ${LUAJIT_BIN}
)
install(FILES tvl1.lua DESTINATION ${LUAJIT_BIN}/lua/IPOL)


