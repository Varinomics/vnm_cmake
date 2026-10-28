cmake_minimum_required(VERSION 3.25)
project(runtime_dlls_test LANGUAGES C CXX)

if(NOT WIN32)
    message(FATAL_ERROR "The runtime DLL integration fixture requires Windows.")
endif()
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/vnm_runtime_dlls.cmake")
enable_testing()

set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreaded)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/runtime")
set(RUNTIME_VALUE 7 CACHE STRING "Value returned by the worker's imported DLL")
configure_file(runtime.c.in runtime.c @ONLY)
add_library(runtime SHARED "${CMAKE_CURRENT_BINARY_DIR}/runtime.c")
set_target_properties(runtime PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/sdk")
add_library(worker SHARED worker.c)
target_link_libraries(worker PRIVATE runtime)
set_target_properties(worker PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/terminal_worker")
add_library(second_worker SHARED worker.c)
target_link_libraries(second_worker PRIVATE runtime)
set_target_properties(second_worker PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/terminal_worker")
add_executable(host host.c)

set(package_dir "$<TARGET_FILE_DIR:worker>")
file(GENERATE OUTPUT "${package_dir}/vnm_package.json" CONTENT "{\"plugin\":\"fixture\"}\n")
file(GENERATE OUTPUT "${package_dir}/resource.txt" CONTENT "worker resource\n")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/additional.txt" "additional runtime file\n")
add_custom_target(runtime_sidecars)
vnm_stage_runtime_dlls(TARGETS worker
    DESTINATION "$<TARGET_FILE_DIR:host>"
    EXTRA_FILES "${CMAKE_CURRENT_BINARY_DIR}/additional.txt"
    AGGREGATE_TARGET runtime_sidecars)
vnm_stage_runtime_dlls(TARGETS second_worker
    DESTINATION "$<TARGET_FILE_DIR:host>"
    EXTRA_FILES "${CMAKE_CURRENT_BINARY_DIR}/additional.txt"
    AGGREGATE_TARGET runtime_sidecars)
add_dependencies(host runtime_sidecars)
vnm_stage_runtime_dlls(TARGETS host
    DESTINATION "$<TARGET_FILE_DIR:host>" POST_BUILD)

add_test(NAME runtime_dlls_layout
    COMMAND "${CMAKE_COMMAND}"
        "-DRUNTIME_DIR=$<TARGET_FILE_DIR:host>"
        "-DWORKER_FILE=$<TARGET_FILE:worker>"
        "-DSECOND_WORKER_FILE=$<TARGET_FILE:second_worker>"
        "-DRUNTIME_FILE=$<TARGET_FILE:runtime>"
        -P "${CMAKE_CURRENT_LIST_DIR}/check_layout.cmake")
add_test(NAME runtime_dlls_host_load
    COMMAND "${CMAKE_COMMAND}" -E env
        "PATH=$ENV{SystemRoot}/System32;$ENV{SystemRoot}"
        "$<TARGET_FILE:host>" "$<TARGET_FILE:worker>" "${RUNTIME_VALUE}")
