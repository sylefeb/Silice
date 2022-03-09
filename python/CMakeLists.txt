cmake_minimum_required(VERSION 2.6)
project(_silice)

include_directories(
  ${PROJECT_SOURCE_DIR}/
  ${PROJECT_SOURCE_DIR}/../src
  ${PROJECT_SOURCE_DIR}/../src/libs
  ${PROJECT_SOURCE_DIR}/../src/libs/LibSL-small/src
  ${PROJECT_SOURCE_DIR}/../src/libs/LibSL-small/src/LibSL
  ${PROJECT_SOURCE_DIR}/../antlr/antlr4-cpp-runtime-4.7.2-source/runtime/src
  ${PROJECT_SOURCE_DIR}/../antlr/
)

link_directories(
  ${PROJECT_SOURCE_DIR}/../lib/
)

if (CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /STACK:4194304")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_definitions(-DANTLR4CPP_STATIC)

# silice python package

add_subdirectory(pybind11)

pybind11_add_module(_silice pysilice.cpp)

target_link_libraries(_silice libsilice lua luabind antlr4-runtime)
if(WIN32)
target_link_libraries(_silice shlwapi)
endif(WIN32)

target_compile_definitions(_silice PRIVATE VERSION_INFO="0.1")

install(TARGETS _silice LIBRARY DESTINATION ${CMAKE_SOURCE_DIR}/silice)

# compiler checks

if (CMAKE_CXX_COMPILER_ID MATCHES "GNU")
  if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS 8)
    message(FATAL_ERROR "Silice requires g++ 8 at least")
  elseif(CMAKE_CXX_COMPILER_VERSION VERSION_LESS 9)
    target_link_libraries(_silice stdc++fs)
  endif()
endif()
