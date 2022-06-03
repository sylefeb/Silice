cmake_minimum_required(VERSION 2.6)
project(silice)

INCLUDE_DIRECTORIES(
  ${PROJECT_SOURCE_DIR}/
  ${PROJECT_SOURCE_DIR}/src
  ${PROJECT_SOURCE_DIR}/src/libs
  ${PROJECT_SOURCE_DIR}/src/libs/tclap/include
  ${PROJECT_SOURCE_DIR}/src/libs/LibSL-small/src
  ${PROJECT_SOURCE_DIR}/src/libs/LibSL-small/src/LibSL
  ${PROJECT_SOURCE_DIR}/src/libs/lua/src
  ${PROJECT_SOURCE_DIR}/src/libs/luabind-deboostified/
  ${PROJECT_SOURCE_DIR}/antlr/antlr4-cpp-runtime-4.7.2-source/runtime/src
  ${PROJECT_SOURCE_DIR}/antlr/
)

if (CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /STACK:4194304")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if (WIN32)
SET(ANTLR_COMPILER ${PROJECT_SOURCE_DIR}/antlr/compile.bat)
else ()
SET(ANTLR_COMPILER ${PROJECT_SOURCE_DIR}/antlr/compile.sh)
endif()

add_custom_command(
  OUTPUT
	${PROJECT_SOURCE_DIR}/antlr/siliceParser.cpp
	${PROJECT_SOURCE_DIR}/antlr/siliceParser.h
	${PROJECT_SOURCE_DIR}/antlr/siliceLexer.cpp
	${PROJECT_SOURCE_DIR}/antlr/siliceLexer.h
  COMMAND ${ANTLR_COMPILER} silice
  MAIN_DEPENDENCY ${PROJECT_SOURCE_DIR}/antlr/silice.g4
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/antlr/
)

add_custom_command(
  OUTPUT
	${PROJECT_SOURCE_DIR}/antlr/vmoduleParser.cpp
	${PROJECT_SOURCE_DIR}/antlr/vmoduleParser.h
	${PROJECT_SOURCE_DIR}/antlr/vmoduleLexer.cpp
	${PROJECT_SOURCE_DIR}/antlr/vmoduleLexer.h
  COMMAND ${ANTLR_COMPILER} vmodule
  MAIN_DEPENDENCY ${PROJECT_SOURCE_DIR}/antlr/vmodule.g4
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/antlr/
)

set(SILICE_CORE
  src/Algorithm.cpp
  src/Algorithm.h
  src/Module.h
  src/LuaPreProcessor.h
  src/LuaPreProcessor.cpp
  src/SiliceCompiler.cpp
  src/SiliceCompiler.h
  src/ParsingContext.cpp
  src/ParsingContext.h
  src/ParsingErrors.cpp
  src/ParsingErrors.h
  src/Config.h
  src/Config.cpp
  src/VerilogTemplate.h
  src/VerilogTemplate.cpp
  src/Config.cpp
  src/TypesAndConsts.cpp
  src/TypesAndConsts.h
  src/ExpressionLinter.cpp
  src/ExpressionLinter.h
  src/RISCVSynthesizer.cpp
  src/RISCVSynthesizer.h
  src/Utils.cpp
  src/Utils.h
  src/Blueprint.cpp
  src/Blueprint.h
  antlr/siliceParser.cpp
  antlr/siliceParser.h
  antlr/siliceLexer.cpp
  antlr/siliceLexer.h
  antlr/vmoduleParser.cpp
  antlr/vmoduleParser.h
  antlr/vmoduleLexer.cpp
  antlr/vmoduleLexer.h
  src/libs/LibSL-small/src/LibSL/System/System.cpp
  src/libs/LibSL-small/src/LibSL/CppHelpers/CppHelpers.cpp
  src/libs/LibSL-small/src/LibSL/StlHelpers/StlHelpers.cpp
  src/libs/LibSL-small/src/LibSL/Image/Image.cpp
  src/libs/LibSL-small/src/LibSL/Image/ImageFormat_TGA.cpp
  src/libs/LibSL-small/src/LibSL/Math/Vertex.cpp
  src/libs/LibSL-small/src/LibSL/Math/Math.cpp
  src/tga.cpp
  src/tga.h
)

add_definitions(-DANTLR4CPP_STATIC)

add_subdirectory(antlr/antlr4-cpp-runtime-4.7.2-source)
add_subdirectory(src/libs/lua)
add_subdirectory(src/libs/luabind-deboostified)

# libsilice

add_library(libsilice STATIC ${SILICE_CORE})

# silice executable

add_executable(silice src/silice.cpp)
# set_target_properties(silice PROPERTIES OUTPUT_NAME "silice")
target_link_libraries(silice libsilice antlr4_static lua luabind)
if(WIN32)
target_link_libraries(silice shlwapi)
endif(WIN32)

install(TARGETS silice RUNTIME DESTINATION ${CMAKE_SOURCE_DIR}/bin)
install(TARGETS libsilice ARCHIVE DESTINATION ${CMAKE_SOURCE_DIR}/lib)
install(TARGETS lua ARCHIVE DESTINATION ${CMAKE_SOURCE_DIR}/lib)
install(TARGETS lua ARCHIVE DESTINATION ${CMAKE_SOURCE_DIR}/lib)
install(TARGETS luabind ARCHIVE DESTINATION ${CMAKE_SOURCE_DIR}/lib)
install(TARGETS antlr4_static ARCHIVE DESTINATION ${CMAKE_SOURCE_DIR}/lib)

# compiler checks

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU" AND
   CMAKE_CXX_COMPILER_VERSION VERSION_LESS 8)
    message(FATAL_ERROR "Silice requires g++ 8 at least")
endif()

set(STD_FS_LIB "")
# ==== The test below is based on https://github.com/pybind/pybind11/blob/master/tests/CMakeLists.txt
# It is under a BSD-style license, see https://github.com/pybind/pybind11/blob/master/LICENSE
#
# Check if we need to add -lstdc++fs or -lc++fs or nothing
if(DEFINED CMAKE_CXX_STANDARD AND CMAKE_CXX_STANDARD LESS 17)
  set(STD_FS_NO_LIB_NEEDED TRUE)
elseif(MSVC)
  set(STD_FS_NO_LIB_NEEDED TRUE)
else()
  file(
    WRITE ${CMAKE_CURRENT_BINARY_DIR}/main.cpp
    "#include <filesystem>\nint main(int argc, char ** argv) {\n  std::filesystem::path p(argv[0]);\n  return p.string().length();\n}"
  )
  try_compile(
    STD_FS_NO_LIB_NEEDED ${CMAKE_CURRENT_BINARY_DIR}
    SOURCES ${CMAKE_CURRENT_BINARY_DIR}/main.cpp
    COMPILE_DEFINITIONS -std=c++17)
  try_compile(
    STD_FS_NEEDS_STDCXXFS ${CMAKE_CURRENT_BINARY_DIR}
    SOURCES ${CMAKE_CURRENT_BINARY_DIR}/main.cpp
    COMPILE_DEFINITIONS -std=c++17
    LINK_LIBRARIES stdc++fs)
  try_compile(
    STD_FS_NEEDS_CXXFS ${CMAKE_CURRENT_BINARY_DIR}
    SOURCES ${CMAKE_CURRENT_BINARY_DIR}/main.cpp
    COMPILE_DEFINITIONS -std=c++17
    LINK_LIBRARIES c++fs)
endif()

if(STD_FS_NEEDS_STDCXXFS)
  set(STD_FS_LIB stdc++fs)
elseif(STD_FS_NEEDS_CXXFS)
  set(STD_FS_LIB c++fs)
elseif(STD_FS_NO_LIB_NEEDED)
  message(WARNING "Unknown C++17 compiler - not passing -lstdc++fs")
endif()
# ==== (end of test for stdc++fs)

if(NOT "${STD_FS_LIB}")
  message(STATUS "Linking with: ${STD_FS_LIB}")
  target_link_libraries(silice ${STD_FS_LIB})
endif()
