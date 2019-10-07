cmake_minimum_required(VERSION 2.6)
project(verilator_silice)

# find_package(verilator) ?

INCLUDE_DIRECTORIES(
  ${PROJECT_SOURCE_DIR}/
  ${PROJECT_SOURCE_DIR}/../../LibSL-small/src
  ${PROJECT_SOURCE_DIR}/../../LibSL-small/src/LibSL  
  /usr/local/share/verilator/include/
)

add_definitions(-Wfatal-errors)

ADD_LIBRARY(verilator_silice
  video_out.cpp
  video_out.h
  VgaChip.cpp
  VgaChip.h
  ../../LibSL-small/src/LibSL/System/System.cpp
  ../../LibSL-small/src/LibSL/CppHelpers/CppHelpers.cpp
  ../../LibSL-small/src/LibSL/StlHelpers/StlHelpers.cpp
  ../../LibSL-small/src/LibSL/Math/Math.cpp
  ../../LibSL-small/src/LibSL/Math/Vertex.cpp
  ../../LibSL-small/src/LibSL/Image/Image.cpp
  ../../LibSL-small/src/LibSL/Image/ImageFormat_TGA.cpp
  ../../LibSL-small/src/LibSL/Image/tga.cpp
)

INSTALL(TARGETS verilator_silice ARCHIVE DESTINATION ${CMAKE_SOURCE_DIR})

