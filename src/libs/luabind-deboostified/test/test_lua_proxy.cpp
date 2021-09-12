// Copyright (c) 2005 Daniel Wallin and Arvid Norberg

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

#include <luabind/lua_proxy.hpp>
#include <luabind/object.hpp>

struct X_tag;

struct X
{
    typedef X_tag lua_proxy_tag;
};

namespace luabind
{
  template<>
  struct lua_proxy_traits<X>
  {
      typedef std::true_type is_specialized;
  };
} // namespace luabind

#define LUABIND_STATIC_ASSERT(expr) static_assert(expr, #expr)

LUABIND_STATIC_ASSERT(luabind::is_lua_proxy_type<X>::value);
LUABIND_STATIC_ASSERT(!luabind::is_lua_proxy_type<X&>::value);
LUABIND_STATIC_ASSERT(!luabind::is_lua_proxy_type<X const&>::value);

LUABIND_STATIC_ASSERT(luabind::is_lua_proxy_arg<X>::value);
LUABIND_STATIC_ASSERT(luabind::is_lua_proxy_arg<X const>::value);
LUABIND_STATIC_ASSERT(luabind::is_lua_proxy_arg<X&>::value);
LUABIND_STATIC_ASSERT(luabind::is_lua_proxy_arg<X const&>::value);
LUABIND_STATIC_ASSERT(!luabind::is_lua_proxy_arg<int>::value);
LUABIND_STATIC_ASSERT(!luabind::is_lua_proxy_arg<int[4]>::value);

LUABIND_STATIC_ASSERT(luabind::is_lua_proxy_arg<X const&>::value);
LUABIND_STATIC_ASSERT(luabind::is_lua_proxy_arg<luabind::object&>::value);
LUABIND_STATIC_ASSERT(luabind::is_lua_proxy_arg<luabind::object const&>::value);

int main()
{
}

