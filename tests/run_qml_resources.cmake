cmake_minimum_required(VERSION 3.16)

# Each case configures the stubbed-Qt fixture in a fresh tree so that no
# generated manifest from an earlier run is visible.
file(REMOVE_RECURSE "${TEST_ROOT}")
execute_process(COMMAND "${CMAKE_COMMAND}"
    -S "${PROVIDER_SOURCE}/tests/qml_resources" -B "${TEST_ROOT}/build"
    -G "${GENERATOR}" "-DCMAKE_MAKE_PROGRAM=${MAKE_PROGRAM}"
    "-DCASE=${CASE}" "-DPROVIDER_SOURCE=${PROVIDER_SOURCE}"
    RESULT_VARIABLE result OUTPUT_VARIABLE output ERROR_VARIABLE error)
if(CASE MATCHES "^collision")
    # Both manifests cannot be kept, so the configure must stop and name them.
    # CMake wraps long error text, so compare with the whitespace collapsed.
    string(REGEX REPLACE "[ \t\r\n]+" " " message "${error}")
    set(first "${TEST_ROOT}/build/inputs/a/resources.qrc")
    set(second "${TEST_ROOT}/build/inputs/b/resources.qrc")
    if(CASE STREQUAL "collision_case")
        set(second "${TEST_ROOT}/build/inputs/c/Resources.qrc")
    endif()
    string(FIND "${message}" "${first}" first_position)
    string(FIND "${message}" "${second}" second_position)
    if(result EQUAL 0 OR first_position LESS 0 OR second_position LESS 0
            OR NOT message MATCHES "rename")
        message(FATAL_ERROR "Case ${CASE}: expected a configure error naming "
            "${first} and ${second} and asking for a rename, got result "
            "${result}:\n${output}\n${error}")
    endif()
    # The refusal must come before the second manifest is written over the
    # first, whatever the filesystem's case rules.
    file(READ "${TEST_ROOT}/build/qml_assets/probe/resources.qrc" kept)
    string(FIND "${kept}" "${TEST_ROOT}/build/inputs/a/asset.txt" kept_position)
    if(kept_position LESS 0)
        message(FATAL_ERROR "Case ${CASE}: the first manifest no longer holds its "
            "asset:\n${kept}")
    endif()
elseif(NOT result EQUAL 0)
    message(FATAL_ERROR "Case ${CASE} failed to configure:\n${output}\n${error}")
endif()
