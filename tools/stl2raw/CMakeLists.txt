cmake_minimum_required(VERSION 2.6)
project(stl2raw)

INCLUDE_DIRECTORIES(
  ${PROJECT_SOURCE_DIR}/
  ${PROJECT_SOURCE_DIR}/../../src/libs/LibSL-small/src
  ${PROJECT_SOURCE_DIR}/../../src/libs/LibSL-small/src/LibSL 
  ${PROJECT_SOURCE_DIR}/../../src/libs/tclap/include
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

ADD_EXECUTABLE(stl2raw
  stl2raw.cpp
  ${PROJECT_SOURCE_DIR}/../../src/libs/LibSL-small/src/LibSL/Math/Vertex.cpp
  ${PROJECT_SOURCE_DIR}/../../src/libs/LibSL-small/src/LibSL/Mesh/Mesh.cpp
  ${PROJECT_SOURCE_DIR}/../../src/libs/LibSL-small/src/LibSL/Mesh/MeshFormat_stl.cpp
  ${PROJECT_SOURCE_DIR}/../../src/libs/LibSL-small/src/LibSL/Mesh/VertexFormat_dynamic.cpp
  ${PROJECT_SOURCE_DIR}/../../src/libs/LibSL-small/src/LibSL/CppHelpers/CppHelpers.cpp
  ${PROJECT_SOURCE_DIR}/../../src/libs/LibSL-small/src/LibSL/System/System.cpp
)

if(WIN32)
target_link_libraries(stl2raw shlwapi)
endif(WIN32)

INSTALL(TARGETS stl2raw RUNTIME DESTINATION ${CMAKE_SOURCE_DIR}/)
