cmake_minimum_required(VERSION 3.16)
project(acquisition_contract LANGUAGES NONE)
include("${PROVIDER_SOURCE}/cmake/vnm_owned_dependency.cmake")

set(origin "${TEST_ROOT}/workspace/consumer")
set(repository "${TEST_ROOT}/workspace/sample_dependency")
if(CASE STREQUAL "explicit")
    set(FETCHCONTENT_SOURCE_DIR_SAMPLE_DEPENDENCY "${repository}")
elseif(CASE STREQUAL "invalid")
    set(FETCHCONTENT_SOURCE_DIR_SAMPLE_DEPENDENCY "${TEST_ROOT}/missing")
elseif(CASE STREQUAL "worktree")
    set(origin "${TEST_ROOT}/linked")
elseif(CASE STREQUAL "existing")
    add_library(sample::dependency INTERFACE IMPORTED)
    set(SAMPLE_FILES_DIRECTORY "${TEST_ROOT}/installed/files")
elseif(CASE STREQUAL "fetch")
    set(origin "${TEST_ROOT}/outside/consumer")
    file(MAKE_DIRECTORY "${origin}")
endif()

# One configure reaches the same producer first through its file contract,
# then through its linked contract, as plot and terminal do in Logonomic.
vnm_acquire_owned_dependency(NAME sample_dependency
    GIT_REPOSITORY "${repository}" SOURCE_ROOT "${origin}"
    FILES_VARIABLE SAMPLE_FILES_DIRECTORY)
vnm_acquire_owned_dependency(NAME sample_dependency
    GIT_REPOSITORY "${repository}" SOURCE_ROOT "${origin}"
    TARGET sample::dependency)
if(NOT TARGET sample::dependency OR NOT SAMPLE_FILES_DIRECTORY)
    message(FATAL_ERROR "Both dependency contracts must remain available")
endif()
if(CASE STREQUAL "fetch")
    FetchContent_GetProperties(sample_dependency)
    execute_process(COMMAND "${vnm_dependency_git}" -C "${sample_dependency_SOURCE_DIR}"
        symbolic-ref --short HEAD OUTPUT_VARIABLE branch
        OUTPUT_STRIP_TRAILING_WHITESPACE RESULT_VARIABLE result)
    if(NOT result EQUAL 0 OR NOT branch STREQUAL "master")
        message(FATAL_ERROR "Owned network fallback must track master: ${branch}")
    endif()
endif()
