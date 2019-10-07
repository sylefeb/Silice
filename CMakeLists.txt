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

CONFIGURE_FILE(
  "${CMAKE_CURRENT_SOURCE_DIR}/src/path.h.in"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/path.h"
  )

ADD_EXECUTABLE(silice
  src/silice.cpp
  src/Algorithm.cpp
  src/Algorithm.h
  src/Module.h
  src/LuaPreProcessor.h
  src/LuaPreProcessor.cpp
  src/VerilogCompiler.h
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
