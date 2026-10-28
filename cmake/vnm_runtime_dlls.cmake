include_guard(GLOBAL)

# Stage native imports beside the executable that loads them. A worker DLL's
# own directory is not necessarily a Windows loader search directory.
# POST_BUILD is for an application that already depends on AGGREGATE_TARGET;
# aggregate staging compares each shared import once without an app relink.
function(vnm_stage_runtime_dlls)
    cmake_parse_arguments(PARSE_ARGV 0 arg "POST_BUILD" "DESTINATION;AGGREGATE_TARGET"
        "TARGETS;EXTRA_FILES")
    list(REMOVE_ITEM arg_KEYWORDS_MISSING_VALUES EXTRA_FILES)
    if(arg_UNPARSED_ARGUMENTS OR arg_KEYWORDS_MISSING_VALUES OR
       NOT arg_TARGETS OR NOT arg_DESTINATION)
        message(FATAL_ERROR
            "vnm_stage_runtime_dlls requires TARGETS and DESTINATION; "
            "optional arguments are EXTRA_FILES, AGGREGATE_TARGET and POST_BUILD.")
    endif()
    if(arg_POST_BUILD AND arg_AGGREGATE_TARGET)
        message(FATAL_ERROR "POST_BUILD cannot also add an aggregate dependency.")
    endif()
    if(NOT WIN32)
        return()
    endif()
    if(arg_AGGREGATE_TARGET AND NOT TARGET "${arg_AGGREGATE_TARGET}")
        message(FATAL_ERROR "Unknown runtime aggregate target: ${arg_AGGREGATE_TARGET}")
    endif()

    foreach(target IN LISTS arg_TARGETS)
        if(NOT TARGET "${target}")
            message(FATAL_ERROR "Unknown runtime target: ${target}")
        endif()
        set(script "${CMAKE_CURRENT_BINARY_DIR}/runtime_dlls/${target}-$<CONFIG>.cmake")
        file(GENERATE OUTPUT "${script}" CONTENT
"set(VNM_RUNTIME_DLLS_LOCK_ROOT [==[${CMAKE_BINARY_DIR}/runtime_dlls/locks]==])
include([==[${CMAKE_CURRENT_FUNCTION_LIST_DIR}/vnm_runtime_dlls_stage.cmake]==])
vnm_stage_runtime_files([==[${arg_DESTINATION}]==]
    [==[$<TARGET_RUNTIME_DLLS:${target}>;${arg_EXTRA_FILES}]==])
")
        if(arg_POST_BUILD)
            add_custom_command(TARGET "${target}" POST_BUILD
                COMMAND "${CMAKE_COMMAND}" -P "${script}"
                VERBATIM)
        else()
            set(stage_target "${target}_runtime_dlls")
            add_custom_target("${stage_target}"
                COMMAND "${CMAKE_COMMAND}" -P "${script}"
                DEPENDS "${target}"
                VERBATIM)
            if(arg_AGGREGATE_TARGET)
                set(group_target "${arg_AGGREGATE_TARGET}_runtime_dlls")
                if(NOT TARGET "${group_target}")
                    set(group_script
                        "${CMAKE_CURRENT_BINARY_DIR}/runtime_dlls/${arg_AGGREGATE_TARGET}.cmake")
                    file(WRITE "${group_script}" "")
                    add_custom_target("${group_target}"
                        COMMAND "${CMAKE_COMMAND}"
                            "-DVNM_RUNTIME_DLLS_CONFIGURATION=$<CONFIG>"
                            -P "${group_script}"
                        VERBATIM)
                    set_property(TARGET "${group_target}"
                        PROPERTY VNM_RUNTIME_DLLS_SCRIPT "${group_script}")
                    add_dependencies("${arg_AGGREGATE_TARGET}" "${group_target}")
                endif()
                get_target_property(group_script "${group_target}" VNM_RUNTIME_DLLS_SCRIPT)
                string(REPLACE "$<CONFIG>" "\${VNM_RUNTIME_DLLS_CONFIGURATION}"
                    include_script "${script}")
                file(APPEND "${group_script}" "include(\"${include_script}\")\n")
                add_dependencies("${group_target}" "${target}")
            endif()
        endif()
    endforeach()
endfunction()
