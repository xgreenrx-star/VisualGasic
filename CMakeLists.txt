cmake_minimum_required(VERSION 3.20)

project(VisualGasic LANGUAGES CXX)

option(BUILD_TESTS "Build the VisualGasic integration test harness" ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(BUILD_TESTS)
    set(GODOT_CPP_LIB "")
    if(UNIX AND NOT APPLE)
        set(GODOT_CPP_LIB "${CMAKE_SOURCE_DIR}/godot-cpp/bin/libgodot-cpp.linux.editor.x86_64.a")
    elseif(APPLE)
        set(GODOT_CPP_LIB "${CMAKE_SOURCE_DIR}/godot-cpp/bin/libgodot-cpp.macos.editor.arm64.a")
    elseif(WIN32)
        set(GODOT_CPP_LIB "${CMAKE_SOURCE_DIR}/godot-cpp/bin/libgodot-cpp.windows.editor.x86_64.lib")
    endif()

    if(NOT GODOT_CPP_LIB OR NOT EXISTS ${GODOT_CPP_LIB})
        message(FATAL_ERROR "godot-cpp static library not found at ${GODOT_CPP_LIB}. Build it first with 'scons platform=<platform> target=editor'.")
    endif()

    add_library(godot_cpp STATIC IMPORTED)
    set_target_properties(godot_cpp PROPERTIES
        IMPORTED_LOCATION ${GODOT_CPP_LIB}
        INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_SOURCE_DIR}/godot-cpp/include;${CMAKE_SOURCE_DIR}/godot-cpp/gen/include"
    )

    set(VISUALGASIC_RUNTIME_SOURCES
        ${CMAKE_SOURCE_DIR}/src/gasic_ai_controller.cpp
        ${CMAKE_SOURCE_DIR}/src/visual_gasic_builtins.cpp
        ${CMAKE_SOURCE_DIR}/src/visual_gasic_compiler.cpp
        ${CMAKE_SOURCE_DIR}/src/visual_gasic_expression_evaluator.cpp
        ${CMAKE_SOURCE_DIR}/src/visual_gasic_instance.cpp
        ${CMAKE_SOURCE_DIR}/src/visual_gasic_instance_expression.cpp
        ${CMAKE_SOURCE_DIR}/src/visual_gasic_instance_statement.cpp
        ${CMAKE_SOURCE_DIR}/src/visual_gasic_language.cpp
        ${CMAKE_SOURCE_DIR}/src/visual_gasic_parser.cpp
        ${CMAKE_SOURCE_DIR}/src/visual_gasic_parser_format.cpp
        ${CMAKE_SOURCE_DIR}/src/visual_gasic_profiler.cpp
        ${CMAKE_SOURCE_DIR}/src/visual_gasic_script.cpp
        ${CMAKE_SOURCE_DIR}/src/visual_gasic_script_cleanup.cpp
        ${CMAKE_SOURCE_DIR}/src/visual_gasic_test_runner.cpp
        ${CMAKE_SOURCE_DIR}/src/visual_gasic_tokenizer.cpp
    )

    add_executable(run_integration_tests
        tests/run_integration_tests.cpp
        ${VISUALGASIC_RUNTIME_SOURCES}
    )

    target_include_directories(run_integration_tests PRIVATE
        ${CMAKE_SOURCE_DIR}/tests
        ${CMAKE_SOURCE_DIR}/src
        ${CMAKE_SOURCE_DIR}
    )

    target_link_libraries(run_integration_tests PRIVATE godot_cpp)

    if(UNIX AND NOT APPLE)
        find_package(Threads REQUIRED)
        target_link_libraries(run_integration_tests PRIVATE Threads::Threads dl)
    endif()
endif()
