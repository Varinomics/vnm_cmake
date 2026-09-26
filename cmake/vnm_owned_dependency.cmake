include_guard(GLOBAL)
include(FetchContent)

# Resolve the one standard FetchContent override before considering automatic
# workspace discovery. An explicit local source is an assertion, not a hint.
function(vnm_find_dependency_source out_var)
    cmake_parse_arguments(PARSE_ARGV 1 arg "" "NAME;REQUIRED_FILE;SOURCE_ROOT" "")
    if(NOT arg_REQUIRED_FILE)
        set(arg_REQUIRED_FILE CMakeLists.txt)
    endif()
    if(NOT arg_SOURCE_ROOT)
        set(arg_SOURCE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
    string(TOUPPER "${arg_NAME}" upper_name)
    set(override "FETCHCONTENT_SOURCE_DIR_${upper_name}")
    if(DEFINED ${override} AND NOT "${${override}}" STREQUAL "")
        get_filename_component(source "${${override}}" ABSOLUTE BASE_DIR "${arg_SOURCE_ROOT}")
        if(NOT EXISTS "${source}/${arg_REQUIRED_FILE}")
            message(FATAL_ERROR "${override} does not contain ${arg_REQUIRED_FILE}: ${source}")
        endif()
        set(${out_var} "${source}" PARENT_SCOPE)
        return()
    endif()

    # Git's common directory belongs to the canonical checkout even when the
    # caller lives in a linked worktree elsewhere on the filesystem.
    set(checkout "${arg_SOURCE_ROOT}")
    find_program(vnm_dependency_git NAMES git)
    if(vnm_dependency_git)
        execute_process(
            COMMAND "${vnm_dependency_git}" -C "${arg_SOURCE_ROOT}" rev-parse --git-common-dir
            RESULT_VARIABLE git_result OUTPUT_VARIABLE common_directory
            ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
        if(git_result EQUAL 0)
            get_filename_component(common_directory "${common_directory}" ABSOLUTE BASE_DIR "${arg_SOURCE_ROOT}")
            get_filename_component(checkout "${common_directory}" DIRECTORY)
        endif()
    endif()
    get_filename_component(workspace "${checkout}" DIRECTORY)
    foreach(candidate IN ITEMS
        "${workspace}/${arg_NAME}"
        "${workspace}/../bsd_licensed/${arg_NAME}"
        "${workspace}/../varinomics/${arg_NAME}")
        if(EXISTS "${candidate}/${arg_REQUIRED_FILE}")
            get_filename_component(candidate "${candidate}" ABSOLUTE)
            set(${out_var} "${candidate}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
    set(${out_var} "" PARENT_SCOPE)
endfunction()

# Third-party source adapters share resolution/population while retaining their
# revision and target construction at the caller. Lexilla, for example, has no
# root CMake project. Owned callers use the master-only wrapper below.
function(vnm_acquire_dependency_sources out_var)
    cmake_parse_arguments(PARSE_ARGV 1 arg "EXCLUDE_FROM_ALL"
        "NAME;GIT_REPOSITORY;GIT_TAG;REQUIRED_FILE;SOURCE_ROOT" "")
    if(NOT arg_SOURCE_ROOT)
        set(arg_SOURCE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
    if(NOT arg_REQUIRED_FILE)
        set(arg_REQUIRED_FILE CMakeLists.txt)
    endif()
    vnm_find_dependency_source(source NAME "${arg_NAME}"
        REQUIRED_FILE "${arg_REQUIRED_FILE}" SOURCE_ROOT "${arg_SOURCE_ROOT}")
    set(exclusion)
    if(arg_EXCLUDE_FROM_ALL)
        if(CMAKE_VERSION VERSION_LESS 3.28)
            message(FATAL_ERROR "EXCLUDE_FROM_ALL requires CMake 3.28")
        endif()
        set(exclusion EXCLUDE_FROM_ALL)
    endif()
    if(source)
        message(STATUS "${arg_NAME}: using local source ${source}")
        FetchContent_Declare(${arg_NAME} SOURCE_DIR "${source}" ${exclusion})
    else()
        message(STATUS "${arg_NAME}: fetching ${arg_GIT_TAG} from ${arg_GIT_REPOSITORY}")
        FetchContent_Declare(${arg_NAME}
            GIT_REPOSITORY "${arg_GIT_REPOSITORY}"
            GIT_TAG "${arg_GIT_TAG}"
            GIT_SHALLOW FALSE
            ${exclusion})
    endif()
    FetchContent_MakeAvailable(${arg_NAME})
    FetchContent_GetProperties(${arg_NAME} SOURCE_DIR source)
    if(arg_REQUIRED_FILE AND NOT EXISTS "${source}/${arg_REQUIRED_FILE}")
        message(FATAL_ERROR "${arg_NAME} does not contain ${arg_REQUIRED_FILE}: ${source}")
    endif()
    set(${out_var} "${source}" PARENT_SCOPE)
endfunction()

# Existing public targets remain authoritative, including imported packages.
# FILES_VARIABLE permits consumers of a producer's file contract to reuse it
# without requiring its optional library (vnm_fonts is usable without Qt).
function(vnm_acquire_owned_dependency)
    cmake_parse_arguments(PARSE_ARGV 0 arg "EXCLUDE_FROM_ALL"
        "NAME;GIT_REPOSITORY;TARGET;FILES_VARIABLE;SOURCE_ROOT" "")
    if(arg_TARGET AND TARGET "${arg_TARGET}")
        return()
    endif()
    if(arg_FILES_VARIABLE)
        if(NOT "${${arg_FILES_VARIABLE}}" STREQUAL "")
            return()
        endif()
    endif()
    set(exclusion)
    if(arg_EXCLUDE_FROM_ALL)
        set(exclusion EXCLUDE_FROM_ALL)
    endif()
    if(NOT arg_SOURCE_ROOT)
        set(arg_SOURCE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
    vnm_acquire_dependency_sources(source NAME "${arg_NAME}"
        GIT_REPOSITORY "${arg_GIT_REPOSITORY}" GIT_TAG master
        SOURCE_ROOT "${arg_SOURCE_ROOT}" ${exclusion})
    if(arg_TARGET AND NOT TARGET "${arg_TARGET}")
        message(FATAL_ERROR "${arg_NAME} did not provide required target ${arg_TARGET}")
    endif()
    if(arg_FILES_VARIABLE)
        if("${${arg_FILES_VARIABLE}}" STREQUAL "")
            message(FATAL_ERROR "${arg_NAME} did not provide ${arg_FILES_VARIABLE}")
        endif()
    endif()
endfunction()
