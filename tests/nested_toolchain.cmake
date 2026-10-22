cmake_minimum_required(VERSION 3.16)

# The oracle is CMake's command-line/cache boundary: a list-valued setting must
# arrive as one argument, and compiler-free inspection must not load a toolchain.
file(MAKE_DIRECTORY "${TEST_ROOT}/producer" "${TEST_ROOT}/consumer")
file(WRITE "${TEST_ROOT}/producer/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.16)
project(context_producer LANGUAGES NONE)
include("${MODULE}")
set(CMAKE_CONFIGURATION_TYPES "Debug;Release")
set(CMAKE_FASTBUILD_CACHE_PATH "${CMAKE_CURRENT_BINARY_DIR}/object cache")
set(CMAKE_FASTBUILD_USE_LIGHTCACHE OFF)
set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_BINARY_DIR}/compiler-required.cmake")
file(WRITE "${CMAKE_TOOLCHAIN_FILE}" "message(FATAL_ERROR \"Compiler toolchain loaded by inspection\")\n")
vnm_write_toolchain_context("${CMAKE_CURRENT_BINARY_DIR}/context.cmake")
]=])
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${TEST_ROOT}/producer" -B "${TEST_ROOT}/producer-build"
    "-DMODULE=${MODULE}"
    RESULT_VARIABLE result)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Context producer configure failed")
endif()
include("${TEST_ROOT}/producer-build/context.cmake")

file(WRITE "${TEST_ROOT}/consumer/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.16)
project(context_consumer LANGUAGES NONE)
get_property(languages GLOBAL PROPERTY ENABLED_LANGUAGES)
if(NOT languages STREQUAL "NONE")
    message(FATAL_ERROR "Inspection enabled languages: ${languages}")
endif()
if(EXPECT_CONFIGURATIONS AND NOT CMAKE_CONFIGURATION_TYPES STREQUAL "Debug;Release")
    message(FATAL_ERROR "Configuration list changed: ${CMAKE_CONFIGURATION_TYPES}")
endif()
if(EXPECT_CACHE_PATH)
    if(NOT CMAKE_FASTBUILD_CACHE_PATH STREQUAL EXPECT_CACHE_PATH)
        message(FATAL_ERROR "FASTBuild cache path changed: ${CMAKE_FASTBUILD_CACHE_PATH}")
    endif()
    if(NOT DEFINED CMAKE_FASTBUILD_USE_LIGHTCACHE OR
       NOT CMAKE_FASTBUILD_USE_LIGHTCACHE STREQUAL "OFF")
        message(FATAL_ERROR "FASTBuild LightCache setting changed: ${CMAKE_FASTBUILD_USE_LIGHTCACHE}")
    endif()
endif()
]=])
set(command "${CMAKE_COMMAND}" -S "${TEST_ROOT}/consumer"
    -B "${TEST_ROOT}/inspection")
vnm_append_toolchain_args(command LANGUAGES NONE)
execute_process(COMMAND ${command} RESULT_VARIABLE result)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Compiler-free consumer configure failed")
endif()

# The second consumer exercises list escaping without activating a compiler.
set(VNM_NESTED_TOOLCHAIN_FILE "")
set(command "${CMAKE_COMMAND}" -S "${TEST_ROOT}/consumer"
    -B "${TEST_ROOT}/list-consumer" -DEXPECT_CONFIGURATIONS=ON
    "-DEXPECT_CACHE_PATH=${TEST_ROOT}/producer-build/object cache")
vnm_append_toolchain_args(command)
execute_process(COMMAND ${command} RESULT_VARIABLE result)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Nested build settings did not survive configure")
endif()
