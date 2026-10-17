cmake_minimum_required(VERSION 3.16)
project(qml_resources_test LANGUAGES NONE)

# Exercise the resource transformation without introducing a compiler or Qt
# dependency into vnm_cmake's tests. Imported executables give the helper its
# normal application resource root; Qt's module commands are replaced by
# recorders of what the helper hands them.
function(qt_add_qml_module target)
    cmake_parse_arguments(PARSE_ARGV 1 arg "NO_GENERATE_QMLDIR"
        "URI;OUTPUT_DIRECTORY;OUTPUT_TARGETS" "")
    set_target_properties(${target} PROPERTIES
        QT_QML_MODULE_URI "${arg_URI}"
        QT_QML_MODULE_OUTPUT_DIRECTORY "${arg_OUTPUT_DIRECTORY}"
        QT_QML_MODULE_NO_GENERATE_QMLDIR "${arg_NO_GENERATE_QMLDIR}")
    set(${arg_OUTPUT_TARGETS} "" PARENT_SCOPE)
endfunction()

function(target_sources target visibility)
    if(NOT visibility STREQUAL "PRIVATE")
        message(FATAL_ERROR "Unexpected resource source visibility: ${visibility}")
    endif()
    set_property(TARGET ${target} APPEND PROPERTY TEST_ASSET_QRCS ${ARGN})
endfunction()

# The manifest the helper generated for a target must still name the asset of
# the input it came from.
function(check_asset target qrc_name asset)
    get_target_property(manifests ${target} TEST_ASSET_QRCS)
    foreach(manifest IN LISTS manifests)
        get_filename_component(name "${manifest}" NAME)
        if(name STREQUAL qrc_name)
            file(READ "${manifest}" contents)
            string(FIND "${contents}" "${asset}" position)
            if(position LESS 0)
                message(FATAL_ERROR "${manifest} lost ${asset}:\n${contents}")
            endif()
            return()
        endif()
    endforeach()
    message(FATAL_ERROR "${target} has no generated manifest named ${qrc_name}: ${manifests}")
endfunction()

# The helper refuses a tree that mixes Release with other configurations; pin
# the fixture to one so multi-config generators configure as single-config do.
set(CMAKE_CONFIGURATION_TYPES "Debug")
include("${PROVIDER_SOURCE}/cmake/vnm_qml_resources.cmake")
set(inputs "${CMAKE_CURRENT_BINARY_DIR}/inputs")
file(MAKE_DIRECTORY "${inputs}")
add_executable(probe IMPORTED)
add_executable(other IMPORTED)

foreach(directory IN ITEMS a b c)
    file(MAKE_DIRECTORY "${inputs}/${directory}")
    file(WRITE "${inputs}/${directory}/asset.txt" "${directory} asset")
    file(WRITE "${inputs}/${directory}/resources.qrc" "<RCC>
<qresource prefix=\"/${directory}\">
<file>asset.txt</file>
</qresource>
</RCC>
")
endforeach()

if(CASE STREQUAL "collision")
    # Qt names a resource after its manifest file, so two manifests of one
    # target with the same name cannot both be kept.
    vnm_add_qml_resources(probe URI Test
        QRC_FILES "${inputs}/a/resources.qrc" "${inputs}/b/resources.qrc")
elseif(CASE STREQUAL "collision_case")
    # Names that differ only in case are one file on a case-insensitive
    # filesystem, so the second manifest would replace the first there.
    file(RENAME "${inputs}/c/resources.qrc" "${inputs}/c/Resources.qrc")
    vnm_add_qml_resources(probe URI Test
        QRC_FILES "${inputs}/a/resources.qrc" "${inputs}/c/Resources.qrc")
elseif(CASE STREQUAL "collision_calls")
    vnm_add_qml_resources(probe URI Test QRC_FILES "${inputs}/a/resources.qrc")
    vnm_add_qml_resources(probe URI Test QRC_FILES "${inputs}/b/resources.qrc")
elseif(CASE STREQUAL "repeat")
    vnm_add_qml_resources(probe URI Test
        QRC_FILES "${inputs}/a/resources.qrc" "${inputs}/a/../a/resources.qrc")
    vnm_add_qml_resources(probe URI Test QRC_FILES "${inputs}/a/resources.qrc")
    check_asset(probe resources.qrc "${inputs}/a/asset.txt")
elseif(CASE STREQUAL "targets")
    vnm_add_qml_resources(probe URI Test QRC_FILES "${inputs}/a/resources.qrc")
    vnm_add_qml_resources(other URI Other QRC_FILES "${inputs}/b/resources.qrc")
    check_asset(probe resources.qrc "${inputs}/a/asset.txt")
    check_asset(other resources.qrc "${inputs}/b/asset.txt")
else()
    message(FATAL_ERROR "Unknown resource test case: ${CASE}")
endif()

if(CMAKE_C_COMPILER OR CMAKE_CXX_COMPILER OR TARGET Qt6::Core)
    message(FATAL_ERROR "Resource transformation tests must remain compiler- and Qt-free")
endif()
