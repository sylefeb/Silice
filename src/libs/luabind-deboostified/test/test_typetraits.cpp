// Copyright (c) 2004 Daniel Wallin and Arvid Norberg

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

#include <luabind/detail/typetraits.hpp>
#include <luabind/detail/pointee_sizeof.hpp>

using namespace luabind;
using namespace luabind::detail;

struct tester {};
struct lua_State;

#define LUABIND_STATIC_ASSERT(expr) static_assert(expr, #expr)

int test_main(lua_State*)
{
	LUABIND_STATIC_ASSERT(is_nonconst_reference<int&>::value);
	LUABIND_STATIC_ASSERT(!is_nonconst_reference<const int&>::value);
	LUABIND_STATIC_ASSERT(is_nonconst_reference<tester&>::value);
	LUABIND_STATIC_ASSERT(!is_nonconst_reference<const tester&>::value);

	LUABIND_STATIC_ASSERT(!is_const_reference<int&>::value);
	LUABIND_STATIC_ASSERT(is_const_reference<const int&>::value);
	LUABIND_STATIC_ASSERT(!is_const_reference<tester&>::value);
	LUABIND_STATIC_ASSERT(is_const_reference<const tester&>::value);

	LUABIND_STATIC_ASSERT(!is_const_pointer<int*>::value);
	LUABIND_STATIC_ASSERT(is_const_pointer<const int*>::value);
    LUABIND_STATIC_ASSERT(!is_const_pointer<tester*>::value);
    LUABIND_STATIC_ASSERT(is_const_pointer<const tester*>::value);

    LUABIND_STATIC_ASSERT(is_nonconst_pointer<int*>::value);
    LUABIND_STATIC_ASSERT(!is_nonconst_pointer<const int*>::value);
    LUABIND_STATIC_ASSERT(is_nonconst_pointer<tester*>::value);
    LUABIND_STATIC_ASSERT(!is_nonconst_pointer<const tester*>::value);

    LUABIND_STATIC_ASSERT(!is_const_reference<const tester>::value);

	return 0;
}
