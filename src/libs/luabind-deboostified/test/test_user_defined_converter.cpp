// Copyright Daniel Wallin 2008. Use, modification and distribution is
// subject to the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#include "test.hpp"
#include <luabind/luabind.hpp>

struct X
{
    X(int value)
      : value(value)
    {}

    int value;
};

namespace luabind {


	/*
		This is the only piece of code that hat non-static compute_score. Fixed it to be static.	
	*/

template <>
struct default_converter<X>
  : native_converter_base<X>
{
    static int compute_score(lua_State* L, int index)
    {
        return cv.compute_score(L, index);
    }

    X to_cpp_deferred(lua_State* L, int index)
    {
        return X(lua_tonumber(L, index));
    }

    void to_lua_deferred(lua_State* L, X const& x)
    {
        lua_pushnumber(L, x.value);
    }

    static default_converter<int> cv;
};

} // namespace luabind

int take(X x)
{
    return x.value;
}

X get(int value)
{
    return X(value);
}

void test_main(lua_State* L)
{
    using namespace luabind;

    module(L) [
        def("take", &take),
        def("get", &get)
    ];

    DOSTRING(L,
        "assert(take(1) == 1)\n"
        "assert(take(2) == 2)\n"
    );

    DOSTRING(L,
        "assert(get(1) == 1)\n"
        "assert(get(2) == 2)\n"
    );
}

