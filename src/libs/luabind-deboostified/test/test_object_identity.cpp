// Copyright (c) 2003 Daniel Wallin and Arvid Norberg

// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
// ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
// TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
// SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
// ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
// OR OTHER DEALINGS IN THE SOFTWARE.


#include "test.hpp"
#include <luabind/luabind.hpp>
#include <luabind/detail/debug.hpp>
#include <luabind/operator.hpp>

#include <utility>

using namespace luabind;


struct test_param : counted_type<test_param>, wrap_base
{
	luabind::object obj;
	luabind::object obj2;

	bool operator==(test_param const& rhs) const
	{ return obj == rhs.obj && obj2 == rhs.obj2; }
};

COUNTER_GUARD(test_param);

static test_param * s_ptr = NULL;

void store_ptr(test_param * ptr) {
	s_ptr = ptr;
}

test_param * get_ptr() {
	return s_ptr;
}

void test_main(lua_State* L)
{
	using namespace luabind;

	module(L)
	[
		class_<test_param>("test_param")
			.def(constructor<>())
			.def_readwrite("obj", &test_param::obj)
			.def_readonly("obj2", &test_param::obj2)
			.def(const_self == const_self)
		,		
		def("store_ptr", &store_ptr),
		def("get_ptr", &get_ptr)
	];

	test_param temp_object;
	globals(L)["temp"] = temp_object;
	
	object tab = newtable(L);
	tab[temp_object] = 1;
	TEST_CHECK( tab[temp_object] == 1 );
	TEST_CHECK( tab[globals(L)["temp"]] == 1 );
	
	DOSTRING(L,
		"local tab = {}\n"
		"tab[temp] = 1\n"
		"assert(tab[temp] == 1)");
	
	// The following assertion fails.
	DOSTRING(L,
		"t = test_param()\n"
		"tab = {}\n"
		"tab[t] = 1\n"
		"store_ptr(t)\n"
		"assert(tab[get_ptr()] == 1)");
}

