include_guard(GLOBAL)
set_property(GLOBAL PROPERTY VNM_NESTED_TOOLCHAIN_MODULE "${CMAKE_CURRENT_LIST_FILE}")

# Write at producer configure time, then include the result from a cmake -P
# harness. Only build-tool settings are recorded; the caller supplies its normal
# developer environment when running compiler-capable harnesses.
function(vnm_write_toolchain_context path)
    get_property(_languages GLOBAL PROPERTY ENABLED_LANGUAGES)
    set(_fields
        GENERATOR GENERATOR_PLATFORM GENERATOR_TOOLSET GENERATOR_INSTANCE
        MAKE_PROGRAM BUILD_TYPE CONFIGURATION_TYPES TOOLCHAIN_FILE LINKER
        RC_COMPILER MT MSVC_DEBUG_INFORMATION_FORMAT
        FASTBUILD_CAPTURE_SYSTEM_ENV FASTBUILD_CACHE_PATH FASTBUILD_USE_LIGHTCACHE
        POLICY_DEFAULT_CMP0141 AUTOGEN_PARALLEL)
    foreach(_language IN LISTS _languages)
        if(NOT _language STREQUAL "NONE")
            list(APPEND _fields "${_language}_COMPILER")
            list(APPEND _fields "${_language}_COMPILER_LAUNCHER")
        endif()
    endforeach()
    list(REMOVE_DUPLICATES _fields)

    set(_content "# Generated nested configure context.\n")
    get_property(_module GLOBAL PROPERTY VNM_NESTED_TOOLCHAIN_MODULE)
    string(APPEND _content "include(\"${_module}\")\n")
    foreach(_field IN LISTS _fields)
        set(_value "${CMAKE_${_field}}")
        if(_field STREQUAL "TOOLCHAIN_FILE" AND NOT _value STREQUAL "")
            if(EXISTS "${CMAKE_BINARY_DIR}/${_value}")
                get_filename_component(_value "${_value}" ABSOLUTE
                    BASE_DIR "${CMAKE_BINARY_DIR}")
            else()
                get_filename_component(_value "${_value}" ABSOLUTE
                    BASE_DIR "${CMAKE_SOURCE_DIR}")
            endif()
        endif()
        # Bracket quoting preserves backslashes, lists, dollars and quotes.
        set(_equals "=")
        while(_value MATCHES "]${_equals}]")
            string(APPEND _equals "=")
        endwhile()
        string(APPEND _content
            "set(VNM_NESTED_${_field} [${_equals}[${_value}]${_equals}])\n")
    endforeach()
    string(APPEND _content "set(VNM_NESTED_FIELDS \"${_fields}\")\n")
    file(WRITE "${path}" "${_content}")
endfunction()

# Append arguments to an existing command list. LANGUAGES NONE deliberately
# excludes toolchain files and compiler settings: package inspection must not
# activate languages through an inherited toolchain.
function(vnm_append_toolchain_args out_var)
    cmake_parse_arguments(PARSE_ARGV 1 _args "" "" "LANGUAGES")
    set(_command "${${out_var}}")
    if(NOT DEFINED VNM_NESTED_FIELDS)
        message(FATAL_ERROR "Include a vnm_write_toolchain_context result first.")
    endif()
    foreach(_field IN LISTS VNM_NESTED_FIELDS)
        if(_args_LANGUAGES STREQUAL "NONE" AND NOT _field MATCHES
           "^(GENERATOR|GENERATOR_PLATFORM|GENERATOR_TOOLSET|GENERATOR_INSTANCE|MAKE_PROGRAM)$")
            continue()
        endif()
        if("${VNM_NESTED_${_field}}" STREQUAL "" OR
           "${VNM_NESTED_${_field}}" MATCHES "-NOTFOUND$")
            continue()
        endif()
        string(REPLACE ";" "\\;" _value "${VNM_NESTED_${_field}}")
        if(_field STREQUAL "GENERATOR")
            list(APPEND _command -G "${_value}")
        elseif(_field STREQUAL "GENERATOR_PLATFORM")
            list(APPEND _command -A "${_value}")
        elseif(_field STREQUAL "GENERATOR_TOOLSET")
            list(APPEND _command -T "${_value}")
        else()
            list(APPEND _command "-DCMAKE_${_field}=${_value}")
        endif()
    endforeach()
    set(${out_var} "${_command}" PARENT_SCOPE)
endfunction()
