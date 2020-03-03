cmake_minimum_required(VERSION 2.6)
project(verilator_silice)

# find_package(verilator) ?

INCLUDE_DIRECTORIES(
  ${PROJECT_SOURCE_DIR}/
  ${PROJECT_SOURCE_DIR}/../../src/libs/LibSL-small/src
  ${PROJECT_SOURCE_DIR}/../../src/libs/LibSL-small/src/LibSL  
  /usr/local/share/verilator/include/
  /usr/share/verilator/include/
)

add_definitions(-Wfatal-errors)

ADD_LIBRARY(verilator_silice
  video_out.cpp
  video_out.h
  sdr_sdram.cpp
  sdr_sdram.h
  VgaChip.cpp
  VgaChip.h
  ../../src/libs/LibSL-small/src/LibSL/System/System.cpp
  ../../src/libs/LibSL-small/src/LibSL/CppHelpers/CppHelpers.cpp
  ../../src/libs/LibSL-small/src/LibSL/StlHelpers/StlHelpers.cpp
  ../../src/libs/LibSL-small/src/LibSL/Math/Math.cpp
  ../../src/libs/LibSL-small/src/LibSL/Math/Vertex.cpp
  ../../src/libs/LibSL-small/src/LibSL/Image/Image.cpp
  ../../src/libs/LibSL-small/src/LibSL/Image/ImageFormat_TGA.cpp
  ../../src/libs/LibSL-small/src/LibSL/Image/tga.cpp
)

INSTALL(TARGETS verilator_silice ARCHIVE DESTINATION ${CMAKE_SOURCE_DIR})

