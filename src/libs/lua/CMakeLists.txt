CMAKE_MINIMUM_REQUIRED(VERSION 2.6)
PROJECT(lua)

SET(LIBLUA_SOURCES 
src/lapi.c      src/lcorolib.c  src/ldump.c   src/llex.c      src/lopcodes.c  src/lstrlib.c  src/luac.c
src/lauxlib.c   src/lctype.c    src/lfunc.c   src/lmathlib.c  src/loslib.c    src/ltable.c   src/lundump.c
src/lbaselib.c  src/ldblib.c    src/lgc.c     src/lmem.c      src/lparser.c   src/ltablib.c  src/lutf8lib.c
src/lbitlib.c   src/ldebug.c    src/linit.c   src/loadlib.c   src/lstate.c    src/ltm.c      src/lvm.c
src/lcode.c     src/ldo.c       src/liolib.c  src/lobject.c   src/lstring.c   src/lua.c      src/lzio.c
)
		
SET(LIBLUA_HEADERS 
src/lapi.h     src/ldebug.h  src/llex.h     src/lopcodes.h  src/lstring.h  src/luaconf.h  src/lzio.h
src/lauxlib.h  src/ldo.h     src/llimits.h  src/lparser.h   src/ltable.h   src/lualib.h
src/lcode.h    src/lfunc.h   src/lmem.h     src/lprefix.h   src/ltm.h      src/lundump.h
src/lctype.h   src/lgc.h     src/lobject.h  src/lstate.h    src/lua.h      src/lvm.h
)
		
ADD_DEFINITIONS( -DLUA_COMPAT_ALL -D_CRT_SECURE_NO_WARNINGS )
	
ADD_LIBRARY(lua STATIC ${LIBLUA_SOURCES} ${LIBLUA_HEADERS})
SET_PROPERTY(TARGET lua APPEND PROPERTY
   INTERFACE_INCLUDE_DIRECTORIES
 			${CMAKE_CURRENT_SOURCE_DIR}/src)

SET_TARGET_PROPERTIES(lua PROPERTIES DEBUG_POSTFIX "-d")

IF(NOT WIN32)
TARGET_LINK_LIBRARIES(lua dl)
ENDIF()

#INSTALL(TARGETS lua
#  RUNTIME DESTINATION ${CMAKE_SOURCE_DIR}/bin/
#  LIBRARY DESTINATION ${CMAKE_SOURCE_DIR}/lib/
#  ARCHIVE DESTINATION ${CMAKE_SOURCE_DIR}/lib/
#)
