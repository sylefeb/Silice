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


if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
# think antlr does stuff that isn't permitted in Clang under newer C++ standard
# => latest Silice requires c++ 17, we'll have to look into this
# set(CMAKE_CXX_STANDARD 14)
endif()

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

add_custom_command(
  OUTPUT 
	${PROJECT_SOURCE_DIR}/antlr/lppParser.cpp 
	${PROJECT_SOURCE_DIR}/antlr/lppParser.h
	${PROJECT_SOURCE_DIR}/antlr/lppLexer.cpp 
	${PROJECT_SOURCE_DIR}/antlr/lppLexer.h
  COMMAND ${ANTLR_COMPILER} lpp
  MAIN_DEPENDENCY ${PROJECT_SOURCE_DIR}/antlr/lpp.g4
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/antlr/
)

ADD_EXECUTABLE(silice
  src/silice.cpp
  src/Algorithm.cpp
  src/Algorithm.h
  src/Module.h
  src/LuaPreProcessor.h
  src/LuaPreProcessor.cpp
  src/SiliceCompiler.cpp
  src/SiliceCompiler.h
  src/Config.h
  src/Config.cpp
  src/VerilogTemplate.h
  src/VerilogTemplate.cpp
  src/Config.cpp
  src/TypesAndConsts.cpp
  src/TypesAndConsts.h
  src/ExpressionLinter.cpp
  src/ExpressionLinter.h
  antlr/siliceParser.cpp
  antlr/siliceParser.h
  antlr/siliceLexer.cpp
  antlr/siliceLexer.h
  antlr/vmoduleParser.cpp
  antlr/vmoduleParser.h
  antlr/vmoduleLexer.cpp
  antlr/vmoduleLexer.h
  antlr/lppParser.cpp
  antlr/lppParser.h
  antlr/lppLexer.cpp
  antlr/lppLexer.h
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

target_link_libraries(silice antlr4_static lua luabind)

if(WIN32)
target_link_libraries(silice shlwapi)
endif(WIN32)

INSTALL(TARGETS silice RUNTIME DESTINATION ${CMAKE_SOURCE_DIR}/bin)
