get_filename_component(worker_dir "${WORKER_FILE}" DIRECTORY)
get_filename_component(runtime_name "${RUNTIME_FILE}" NAME)
foreach(path IN ITEMS
        "${WORKER_FILE}"
        "${SECOND_WORKER_FILE}"
        "${worker_dir}/vnm_package.json"
        "${worker_dir}/resource.txt"
        "${RUNTIME_DIR}/${runtime_name}"
        "${RUNTIME_DIR}/additional.txt")
    if(NOT EXISTS "${path}")
        message(FATAL_ERROR "Missing runtime payload file: ${path}")
    endif()
endforeach()
file(SHA256 "${RUNTIME_FILE}" source_hash)
file(SHA256 "${RUNTIME_DIR}/${runtime_name}" staged_hash)
if(NOT source_hash STREQUAL staged_hash)
    message(FATAL_ERROR "The staged runtime DLL does not match its producer.")
endif()
file(GLOB packaged_dlls "${RUNTIME_DIR}/*.dll" "${worker_dir}/*.dll")
list(LENGTH packaged_dlls dll_count)
if(NOT dll_count EQUAL 3)
    message(FATAL_ERROR "Expected two workers and one shared native runtime: ${packaged_dlls}")
endif()
