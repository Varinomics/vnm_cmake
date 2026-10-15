include_guard(GLOBAL)

# Keep the selected QRC (including generated edition selections) as the URL
# manifest. Qt owns compilation of QML; the remaining QRC owns ordinary assets.
# Set VNM_QML_SHORT_SOURCE_PATHS on the target before its first call when Qt's
# generated cache filenames need shorter physical paths. Resource URLs stay fixed.
function(vnm_add_qml_resources target)
    cmake_parse_arguments(PARSE_ARGV 1 arg "GENERATE_QMLDIR" "URI;VERSION;RESOURCE_PREFIX"
        "QRC_FILES;QML_FILES;RESOURCES")
    get_target_property(module_uri ${target} QT_QML_MODULE_URI)
    get_target_property(target_type ${target} TYPE)
    if(NOT module_uri)
        if(NOT arg_URI)
            set(arg_URI "${target}")
        endif()
        if(NOT DEFINED arg_RESOURCE_PREFIX)
            set(arg_RESOURCE_PREFIX "/")
        endif()
        set(module_options "")
        if(NOT arg_GENERATE_QMLDIR)
            list(APPEND module_options NO_GENERATE_QMLDIR NO_GENERATE_QMLTYPES)
        endif()
        if(arg_VERSION)
            list(APPEND module_options VERSION "${arg_VERSION}")
        endif()
        if(target_type STREQUAL "EXECUTABLE")
            list(APPEND module_options NO_RESOURCE_TARGET_PATH)
            set(module_root "${arg_RESOURCE_PREFIX}")
        else()
            list(APPEND module_options NO_PLUGIN)
            string(REPLACE "." "/" module_path "${arg_URI}")
            set(module_root "${arg_RESOURCE_PREFIX}/${module_path}")
        endif()
        string(REGEX REPLACE "/+" "/" module_root "${module_root}")
        string(REGEX REPLACE "/$" "" module_root "${module_root}")
        if(CMAKE_CONFIGURATION_TYPES)
            set(configurations ${CMAKE_CONFIGURATION_TYPES})
        else()
            set(configurations "${CMAKE_BUILD_TYPE}")
        endif()
        list(LENGTH configurations configuration_count)
        if("Release" IN_LIST configurations)
            if(configuration_count GREATER 1)
                message(FATAL_ERROR
                    "Qt DISCARD_QML_CONTENTS is fixed at configure time. "
                    "Use separate Release and non-Release build trees, or set "
                    "CMAKE_CONFIGURATION_TYPES to Release alone.")
            endif()
            list(APPEND module_options DISCARD_QML_CONTENTS)
        endif()
        set(module_output_directory "${CMAKE_CURRENT_BINARY_DIR}/qml_modules/${target}")
        if(arg_GENERATE_QMLDIR)
            string(REPLACE "." "/" module_path "${arg_URI}")
            set(module_output_directory "${CMAKE_CURRENT_BINARY_DIR}/qml_modules/${module_path}")
        endif()
        if(NOT arg_GENERATE_QMLDIR)
            # Qt's cache compiler also requires a tooling qmldir when its
            # generation is disabled. The selected QRC can supply its contents.
            file(MAKE_DIRECTORY "${module_output_directory}")
            file(WRITE "${module_output_directory}/qmldir" "module ${arg_URI}\n")
        endif()
        qt_add_qml_module(${target}
            URI "${arg_URI}"
            RESOURCE_PREFIX "${arg_RESOURCE_PREFIX}"
            OUTPUT_DIRECTORY "${module_output_directory}"
            OUTPUT_TARGETS resource_targets
            ${module_options})
        set_property(TARGET ${target} PROPERTY VNM_QML_RESOURCE_ROOT "${module_root}")
        set_property(TARGET ${target} APPEND PROPERTY
            VNM_QML_RESOURCE_TARGETS ${resource_targets})
    endif()
    get_target_property(module_root ${target} VNM_QML_RESOURCE_ROOT)
    get_target_property(module_output_directory ${target} QT_QML_MODULE_OUTPUT_DIRECTORY)
    get_target_property(no_generate_qmldir ${target} QT_QML_MODULE_NO_GENERATE_QMLDIR)

    get_target_property(short_source_paths ${target} VNM_QML_SHORT_SOURCE_PATHS)
    if(short_source_paths)
        string(MD5 qml_source_key "${target}")
        get_property(qml_source_owner DIRECTORY PROPERTY "VNM_QML_SOURCE_OWNER_${qml_source_key}")
        if(qml_source_owner AND NOT qml_source_owner STREQUAL target)
            message(FATAL_ERROR
                "QML source directory collision between ${qml_source_owner} and ${target}")
        endif()
        set_property(DIRECTORY PROPERTY "VNM_QML_SOURCE_OWNER_${qml_source_key}" "${target}")
        set(qml_source_directory "${CMAKE_CURRENT_BINARY_DIR}/qs/${qml_source_key}")
    else()
        set(qml_source_directory "${CMAKE_CURRENT_BINARY_DIR}/qml_sources/${target}")
    endif()

    set(qml_files ${arg_QML_FILES})
    foreach(qrc IN LISTS arg_QRC_FILES)
        get_filename_component(qrc "${qrc}" ABSOLUTE)
        get_filename_component(qrc_directory "${qrc}" DIRECTORY)
        get_filename_component(qrc_name "${qrc}" NAME)
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${qrc}")
        file(STRINGS "${qrc}" lines)
        set(asset_qrc "")
        foreach(line IN LISTS lines)
            if(line MATCHES "<qresource[^>]*prefix=\"([^\"]*)\"")
                set(prefix "${CMAKE_MATCH_1}")
            endif()
            if(line MATCHES "<file[^>]*>([^<]+)</file>")
                set(source "${CMAKE_MATCH_1}")
                set(alias "${source}")
                get_filename_component(source "${source}" ABSOLUTE
                    BASE_DIR "${qrc_directory}")
                if(line MATCHES "alias=\"([^\"]+)\"")
                    set(alias "${CMAKE_MATCH_1}")
                else()
                    string(REPLACE "<file" "<file alias=\"${alias}\"" line "${line}")
                endif()
                set(resource_url "${prefix}/${alias}")
                string(REGEX REPLACE "/+" "/" resource_url "${resource_url}")
                if(source MATCHES "\\.(qml|js|mjs)$")
                    string(FIND "${resource_url}" "${module_root}/" root_position)
                    if(NOT root_position EQUAL 0)
                        message(FATAL_ERROR
                            "${resource_url} is outside ${target}'s QML module root "
                            "${module_root}/")
                    endif()
                    string(LENGTH "${module_root}/" root_length)
                    string(SUBSTRING "${resource_url}" ${root_length} -1 qml_alias)
                    # One source can appear at several QRC aliases. A per-URL
                    # configured copy also keeps source properties target-local.
                    set(qml_source
                        "${qml_source_directory}/${qml_alias}")
                    configure_file("${source}" "${qml_source}" COPYONLY)
                    set_source_files_properties("${qml_source}" PROPERTIES
                        QT_RESOURCE_ALIAS "${qml_alias}")
                    list(APPEND qml_files "${qml_source}")
                    continue()
                endif()
                if(no_generate_qmldir AND resource_url STREQUAL "${module_root}/qmldir")
                    configure_file("${source}" "${module_output_directory}/qmldir" COPYONLY)
                endif()
                string(REGEX REPLACE ">[^<]+</file>" ">${source}</file>" line "${line}")
            endif()
            string(APPEND asset_qrc "${line}\n")
        endforeach()
        set(asset_qrc_path "${CMAKE_CURRENT_BINARY_DIR}/qml_assets/${target}/${qrc_name}")
        get_filename_component(asset_directory "${asset_qrc_path}" DIRECTORY)
        file(MAKE_DIRECTORY "${asset_directory}")
        file(WRITE "${asset_qrc_path}" "${asset_qrc}")
        set_property(TARGET ${target} PROPERTY AUTORCC ON)
        target_sources(${target} PRIVATE "${asset_qrc_path}")
    endforeach()
    if(qml_files OR arg_RESOURCES)
        qt_target_qml_sources(${target}
            QML_FILES ${qml_files}
            RESOURCES ${arg_RESOURCES}
            OUTPUT_TARGETS resource_targets)
        set_property(TARGET ${target} APPEND PROPERTY
            VNM_QML_RESOURCE_TARGETS ${resource_targets})
    endif()
endfunction()
