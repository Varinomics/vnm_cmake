include_guard(GLOBAL)

# Stage native imports beside the executable that loads them. A worker DLL's
# own directory is not necessarily a Windows loader search directory.
# POST_BUILD is for an application that already depends on AGGREGATE_TARGET;
# sidecars use always-run staging targets so their changes need no app relink.
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
"set(files [==[$<TARGET_RUNTIME_DLLS:${target}>;${arg_EXTRA_FILES}]==])
set(destination [==[${arg_DESTINATION}]==])
list(FILTER files EXCLUDE REGEX \"^$\")
list(REMOVE_DUPLICATES files)
if(files)
    file(MAKE_DIRECTORY \"\${destination}\")
    foreach(runtime_file IN LISTS files)
        get_filename_component(name \"\${runtime_file}\" NAME)
        file(COPY_FILE \"\${runtime_file}\" \"\${destination}/\${name}\"
            ONLY_IF_DIFFERENT)
    endforeach()
endif()
")
        if(arg_POST_BUILD)
            add_custom_command(TARGET "${target}" POST_BUILD
                COMMAND "${CMAKE_COMMAND}" -P "${script}"
                VERBATIM)
        else()
            set(stage_target "${target}_runtime_dlls")
            set(dependencies "${target}")
            # Serialize writers: several sidecars can import the same DLL.
            get_property(previous_stage GLOBAL PROPERTY VNM_RUNTIME_DLL_STAGE_LAST)
            if(previous_stage)
                list(APPEND dependencies "${previous_stage}")
            endif()
            add_custom_target("${stage_target}"
                COMMAND "${CMAKE_COMMAND}" -P "${script}"
                DEPENDS ${dependencies}
                VERBATIM)
            set_property(GLOBAL PROPERTY VNM_RUNTIME_DLL_STAGE_LAST "${stage_target}")
            if(arg_AGGREGATE_TARGET)
                add_dependencies("${arg_AGGREGATE_TARGET}" "${stage_target}")
            endif()
        endif()
    endforeach()
endfunction()
