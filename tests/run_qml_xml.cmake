cmake_minimum_required(VERSION 3.16)

find_package(Python3 REQUIRED COMPONENTS Interpreter)
execute_process(COMMAND "${Python3_EXECUTABLE}"
    "${PROVIDER_SOURCE}/tests/qml_xml.py"
    --provider "${PROVIDER_SOURCE}" --work "${TEST_ROOT}"
    --cmake "${CMAKE_COMMAND}" --generator "${GENERATOR}" --make-program "${MAKE_PROGRAM}"
    RESULT_VARIABLE result)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "QRC XML contract failed")
endif()
