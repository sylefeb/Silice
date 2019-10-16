cmake_minimum_required(VERSION 2.6)
project(verilog-vcd-parser)

INCLUDE_DIRECTORIES(
  ${PROJECT_SOURCE_DIR}/
)

ADD_LIBRARY(verilog-vcd-parser
	src/VCDFile.cpp
	src/VCDFile.hpp
	src/VCDFileParser.cpp
	src/VCDFileParser.hpp
	src/VCDParser.cpp
	src/VCDParser.hpp
	src/VCDScanner.cpp
	src/VCDScanner.hpp
	src/VCDTypes.hpp
	src/VCDValue.cpp
	src/VCDValue.hpp
	src/location.hh
	src/position.hh
	src/stack.hh
)

