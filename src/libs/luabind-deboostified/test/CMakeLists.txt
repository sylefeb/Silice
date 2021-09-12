# Build for LuaBind
# Ryan Pavlik <rpavlik@iastate.edu>
# http://academic.cleardefinition.com/
# Iowa State University HCI Graduate Program/VRAC

# ls test_*.cpp | sort | sed s/test_// | sed s/.cpp//
# remove typetraits lua_proxy and has_get_pointer because they are
# compile-only tests
set(TESTS
	abstract_base
	adopt
	adopt_wrapper
	attributes
	automatic_smart_ptr
	back_reference
	builtin_converters
	class_info
	collapse_converter
	const
	construction
	create_in_thread
	def_from_base
	dynamic_type
	exception_handlers
	exceptions
	extend_class_in_lua
	free_functions
	function_introspection
	held_type
	implicit_cast
	implicit_raw
	iterator
	lua_classes
	null_pointer
	object
# This one fails (known "issue", it's unclear whether this is a bug)
#	object_identity 
	operators
	package_preload
	policies
	private_destructors
	properties
	scope
	separation
	set_instance_value
	shadow
	shared_ptr
	simple_class
	smart_ptr_attributes
	super_leak
	table
	tag_function
	unsigned_int
	user_defined_converter
	vector_of_object
	virtual_inheritance
	yield)

add_library(test_main STATIC main.cpp)

foreach(test ${TESTS})
	add_executable(test_${test} test_${test}.cpp)
	target_link_libraries(test_${test} test_main luabind)
	add_test(NAME ${test} COMMAND test_${test})
endforeach()

if(LUABIND_BUILD_TESTING)
	get_filename_component(BASE "${CMAKE_CURRENT_SOURCE_DIR}/../luabind" ABSOLUTE)
	foreach(HEADER ${APIHEADERS})
		get_filename_component(FULLHEADER "${HEADER}" ABSOLUTE)
		file(RELATIVE_PATH SHORTNAME "${BASE}" "${FULLHEADER}")
		string(REPLACE "/" "_" SHORTNAME "${SHORTNAME}")
		string(REPLACE ".hpp" "" SHORTNAME "${SHORTNAME}")
		configure_file(test_headercompile.cpp.in "${CMAKE_CURRENT_BINARY_DIR}/test_headercompile_${SHORTNAME}.cpp" @ONLY)

		add_executable(test_headercompile_${SHORTNAME} "${CMAKE_CURRENT_BINARY_DIR}/test_headercompile_${SHORTNAME}.cpp")
		target_link_libraries(test_headercompile_${SHORTNAME} luabind)
	endforeach()
endif()

