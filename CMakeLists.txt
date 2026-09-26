cmake_minimum_required(VERSION 3.16)
project(vnm_cmake VERSION 0.1.0 LANGUAGES NONE)

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/vnm_owned_dependency.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/vnm_nested_toolchain.cmake")

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    install(DIRECTORY cmake/ DESTINATION share/vnm_cmake)
    install(FILES vnm_cmake-config.cmake DESTINATION share/vnm_cmake)
    install(FILES LICENSE.txt DESTINATION share/doc/vnm_cmake)
    enable_testing()
    add_subdirectory(tests)
endif()
