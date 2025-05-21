cmake_minimum_required(VERSION 3.16)

project(Nes VERSION 0.1.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "-Wall -Wextra -pedantic -fdiagnostics-color=always -g3")
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

add_subdirectory(src)

# include(cmake/fetch_gtest.cmake)
option(TESTING "Enable tests" OFF)

if (TESTING)
include (CTest)
    enable_testing()
    add_subdirectory(test)
endif ()
