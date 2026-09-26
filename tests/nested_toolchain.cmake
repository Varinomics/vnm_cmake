cmake_minimum_required(VERSION 3.16)

# The oracle is CMake's command-line/cache boundary: a list-valued setting must
# arrive as one argument, and compiler-free inspection must not load a toolchain.
file(MAKE_DIRECTORY "${TEST_ROOT}/producer" "${TEST_ROOT}/consumer")
file(WRITE "${TEST_ROOT}/producer/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.16)
project(context_producer LANGUAGES NONE)
include("${MODULE}")
set(CMAKE_CONFIGURATION_TYPES "Debug;Release")
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
    -B "${TEST_ROOT}/list-consumer" -DEXPECT_CONFIGURATIONS=ON)
vnm_append_toolchain_args(command)
execute_process(COMMAND ${command} RESULT_VARIABLE result)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "List-valued nested setting did not survive configure")
endif()
