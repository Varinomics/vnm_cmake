cmake_minimum_required(VERSION 3.16)
project(qrc_xml_contract LANGUAGES NONE)

# Record the boundary to Qt without introducing a compiler into XML tests.
function(qt_add_qml_module target)
    cmake_parse_arguments(PARSE_ARGV 1 arg "NO_GENERATE_QMLDIR"
        "URI;OUTPUT_DIRECTORY;OUTPUT_TARGETS" "")
    set_target_properties(${target} PROPERTIES
        QT_QML_MODULE_URI "${arg_URI}"
        QT_QML_MODULE_OUTPUT_DIRECTORY "${arg_OUTPUT_DIRECTORY}"
        QT_QML_MODULE_NO_GENERATE_QMLDIR "${arg_NO_GENERATE_QMLDIR}")
    set(${arg_OUTPUT_TARGETS} "" PARENT_SCOPE)
endfunction()

function(qt_target_qml_sources target)
    cmake_parse_arguments(PARSE_ARGV 1 arg "" "OUTPUT_TARGETS" "QML_FILES;RESOURCES")
    foreach(source IN LISTS arg_QML_FILES)
        get_source_file_property(alias "${source}" QT_RESOURCE_ALIAS)
        file(APPEND "${CMAKE_CURRENT_BINARY_DIR}/qml_handoff.tsv" "${alias}\t${source}\n")
    endforeach()
    set(${arg_OUTPUT_TARGETS} "" PARENT_SCOPE)
endfunction()

function(target_sources target visibility)
    foreach(source IN LISTS ARGN)
        file(APPEND "${CMAKE_CURRENT_BINARY_DIR}/asset_handoff.txt" "${source}\n")
    endforeach()
endfunction()

include("${PROVIDER_SOURCE}/cmake/vnm_qml_resources.cmake")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/qml_handoff.tsv" "")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/asset_handoff.txt" "")
add_executable(probe IMPORTED)
vnm_add_qml_resources(probe URI Contract QRC_FILES ${INPUT_QRCS})
if(CMAKE_C_COMPILER OR CMAKE_CXX_COMPILER OR TARGET Qt6::Core)
    message(FATAL_ERROR "The transformation fixture must not enable compilers or Qt libraries")
endif()
