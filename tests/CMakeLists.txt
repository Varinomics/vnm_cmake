foreach(case IN ITEMS explicit invalid workspace worktree existing fetch)
    add_test(NAME acquisition_${case}
        COMMAND "${CMAKE_COMMAND}"
            "-DCASE=${case}"
            "-DTEST_ROOT=${CMAKE_CURRENT_BINARY_DIR}/${case}"
            "-DPROVIDER_SOURCE=${PROJECT_SOURCE_DIR}"
            "-DMAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}"
            "-DGENERATOR=${CMAKE_GENERATOR}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/run_acquisition.cmake")
endforeach()

add_test(NAME nested_toolchain
    COMMAND "${CMAKE_COMMAND}"
        "-DMODULE=${PROJECT_SOURCE_DIR}/cmake/vnm_nested_toolchain.cmake"
        "-DTEST_ROOT=${CMAKE_CURRENT_BINARY_DIR}/nested_toolchain"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/nested_toolchain.cmake")
