# Embedded build for LuaBind
# 2009-2011 Ryan Pavlik <rpavlik@iastate.edu>
# http://academic.cleardefinition.com/
# Iowa State University HCI Graduate Program/VRAC

set(SOURCES
	adopt.rst
	building.rst
	copy.rst
	dependency.rst
	discard_result.rst
	docs.rst
	out_value.rst
	pure_out_value.rst
	raw.rst
	return_reference_to.rst
	return_stl_iterator.rst
	style.css
	yield.rst)

set(SOURCES_COPIED)
foreach(SOURCE ${SOURCES})
	add_custom_command(OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${SOURCE}"
		COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/${SOURCE}" "${CMAKE_CURRENT_BINARY_DIR}/${SOURCE}"
		DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${SOURCE}"
		COMMENT "Copying ${SOURCE}")
	list(APPEND SOURCES_COPIED "${CMAKE_CURRENT_BINARY_DIR}/${SOURCE}")
endforeach()

include(GetGitRevisionDescription.cmake)
git_describe(GIT_DESCRIPTION)
if(GIT_DESCRIPTION)
	string(REGEX REPLACE "^v" "" DOCS_VERSION "${GIT_DESCRIPTION}")
else()
	set(DOCS_VERSION "${CPACK_PACKAGE_VERSION}")
endif()

configure_file(version.rst.in "${CMAKE_CURRENT_BINARY_DIR}/version.rst")
list(APPEND SOURCES "${CMAKE_CURRENT_BINARY_DIR}/version.rst")

find_program(RST2HTML_EXECUTABLE
	NAMES
	rst2html
	rst2html.py)

if(RST2HTML_EXECUTABLE)
	add_custom_command(OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/docs.html"
		COMMAND ${RST2HTML_EXECUTABLE} --traceback -gdt --stylesheet=style.css --link-stylesheet docs.rst > docs.html
		WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
		DEPENDS ${SOURCES_COPIED}
		VERBATIM
		COMMENT "Generating HTML documentation with rst2html")
	add_custom_target(doc DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/docs.html")
endif()
		
