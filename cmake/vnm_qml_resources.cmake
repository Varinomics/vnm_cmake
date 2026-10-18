include_guard(GLOBAL)
set_property(GLOBAL PROPERTY VNM_QML_RESOURCE_ADAPTER
    "${CMAKE_CURRENT_LIST_DIR}/vnm_qml_resources.py")

# Keep the selected QRC (including generated edition selections) as the URL
# manifest. Qt owns compilation of QML; the remaining QRC owns ordinary assets.
# Set VNM_QML_SHORT_SOURCE_PATHS on the target before its first call when Qt's
# generated cache filenames need shorter physical paths. Resource URLs stay fixed.
function(vnm_add_qml_resources target)
    cmake_parse_arguments(PARSE_ARGV 1 arg "GENERATE_QMLDIR" "URI;VERSION;RESOURCE_PREFIX"
        "QRC_FILES;QML_FILES;RESOURCES")
    get_target_property(module_uri ${target} QT_QML_MODULE_URI)
    get_target_property(target_type ${target} TYPE)
    get_target_property(android_type ${target} _qt_android_target_type)
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
        # Qt represents an Android application as a marked module library.
        if(target_type STREQUAL "EXECUTABLE" OR android_type STREQUAL "APPLICATION")
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

    if(arg_QRC_FILES)
        find_package(Python3 REQUIRED COMPONENTS Interpreter)
        get_property(qrc_adapter GLOBAL PROPERTY VNM_QML_RESOURCE_ADAPTER)
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${qrc_adapter}")
    endif()
    set(qml_files ${arg_QML_FILES})
    foreach(qrc IN LISTS arg_QRC_FILES)
        get_filename_component(qrc "${qrc}" ABSOLUTE)
        get_filename_component(qrc_name "${qrc}" NAME)
        # The transformed manifest is written to qml_assets/<target>/<file name>
        # and keeps that name, which Q_INIT_RESOURCE users reference, so a second
        # manifest of the same name would silently replace the first. Names are
        # compared ignoring case: on a case-insensitive filesystem a name that
        # differs only by case is the same file, and such a set is not portable
        # anyway. The helper may be called several times for one target, hence
        # the record on the target.
        string(TOLOWER "${qrc_name}" qrc_key)
        get_property(recorded_qrc TARGET ${target} PROPERTY "VNM_QML_QRC_${qrc_key}")
        if(recorded_qrc AND NOT recorded_qrc STREQUAL qrc)
            message(FATAL_ERROR
                "QRC_FILES of ${target} contain two manifests whose file names "
                "are equal ignoring case: ${recorded_qrc} and ${qrc}. The helper "
                "keeps each manifest under its file name in one directory per "
                "target, so rename one of them.")
        endif()
        set_property(TARGET ${target} PROPERTY "VNM_QML_QRC_${qrc_key}" "${qrc}")
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${qrc}")
        set(asset_qrc_path "${CMAKE_CURRENT_BINARY_DIR}/qml_assets/${target}/${qrc_name}")
        set(entries_path "${asset_qrc_path}.cmake")
        execute_process(COMMAND "${Python3_EXECUTABLE}" "${qrc_adapter}"
            "${qrc}" "${asset_qrc_path}" "${entries_path}"
            RESULT_VARIABLE result ERROR_VARIABLE error)
        if(NOT result EQUAL 0)
            message(FATAL_ERROR "Cannot transform QRC ${qrc}:\n${error}")
        endif()
        include("${entries_path}")
        foreach(entry IN LISTS vnm_qrc_entries)
            set(source "${vnm_qrc_source_${entry}}")
            set(resource_url "${vnm_qrc_url_${entry}}")
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
                set(qml_source "${qml_source_directory}/${qml_alias}")
                configure_file("${source}" "${qml_source}" COPYONLY)
                set_source_files_properties("${qml_source}" PROPERTIES
                    QT_RESOURCE_ALIAS "${qml_alias}")
                list(APPEND qml_files "${qml_source}")
            elseif(no_generate_qmldir AND resource_url STREQUAL "${module_root}/qmldir")
                configure_file("${source}" "${module_output_directory}/qmldir" COPYONLY)
            endif()
        endforeach()
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
