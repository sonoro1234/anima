cmake_minimum_required(VERSION 2.8.7)
project(of)

if(!MSVC)
add_subdirectory(tvl1)
add_subdirectory(horn)
endif()
add_subdirectory(brox)



