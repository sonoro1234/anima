cmake_minimum_required(VERSION 3.13)
project(of)

if(NOT MSVC)
add_subdirectory(tvl1)
add_subdirectory(horn)
endif()
add_subdirectory(brox)



