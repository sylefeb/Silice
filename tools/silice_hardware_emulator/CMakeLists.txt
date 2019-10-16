cmake_minimum_required(VERSION 2.6)
project(silice_hardware_emulator)

ADD_SUBDIRECTORY(libs/verilog-vcd-parser)
ADD_SUBDIRECTORY(libs/LibSL)

INCLUDE_DIRECTORIES(
  ${PROJECT_SOURCE_DIR}/
  ${PROJECT_SOURCE_DIR}/libs/verilog-vcd-parser/src/
)

ADD_EXECUTABLE(silicehe
  src/main.cpp
  src/video_out.cpp
  src/video_out.h
  src/VgaChip.cpp
  src/VgaChip.h
)

TARGET_LINK_LIBRARIES(silicehe verilog-vcd-parser LibSL LibSL_gl)

