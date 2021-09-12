// Copyright Daniel Wallin 2009. Use, modification and distribution is
// subject to the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#include "test.hpp"
#include <luabind/luabind.hpp>

struct X
{
    X(int x, int y)
      : x(x)
      , y(y)
    {}

    int x;
    int y;
};

namespace luabind {

int combine_score(int s1, int s2)
{
//    if (s1 < 0 || s2 < 0) return -1;
    return s1 + s2;
}

template <>
struct default_converter<X>
  : native_converter_base<X>
{
	enum { consumed_args = 2 };

    static int compute_score(lua_State* L, int index)
    {
        return combine_score(
			default_converter<int>::compute_score(L, index), default_converter<int>::compute_score(L, index + 1));
    }

    X to_cpp_deferred(lua_State* L, int index)
    {
        return X(lua_tonumber(L, index), lua_tonumber(L, index + 1));
    }

	// static compute_score ...
    //default_converter<int> c1;
    //default_converter<int> c2;
};

} // namespace luabind

int take(X x)
{
    return x.x + x.y;
}

void test_main(lua_State* L)
{
    using namespace luabind;

    module(L) [
        def("take", &take)
    ];

    DOSTRING(L,
        "assert(take(1,1) == 2)\n"
        "assert(take(2,3) == 5)\n"
    );
}

