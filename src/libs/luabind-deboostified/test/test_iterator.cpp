// Copyright Daniel Wallin 2007. Use, modification and distribution is
// subject to the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#include "test.hpp"

#include <luabind/luabind.hpp>
#include <luabind/iterator_policy.hpp>
#include <luabind/detail/crtp_iterator.hpp>

struct container
{
    container()
    {
        for (int i = 0; i < 5; ++i)
            data[i] = i + 1;
    }

    struct iterator
		: public luabind::detail::crtp_iterator< iterator, std::forward_iterator_tag, int >
    {
        static std::size_t alive;

        iterator(int* p)
			: p_(p)
        {
            ++alive;
        }

		iterator(const iterator& other)
			: p_(other.p_)
		{
			++alive;
		}

		void increment() {
			++p_;
		}

		int& dereference() {
			return *p_;
		}

		bool equal(const iterator& other) const
		{
			return p_ == other.p_;
		}

        ~iterator()
        {
            --alive;
        }

	private:
		int* p_;
    };

    iterator begin()
    {
        return iterator(data);
    }

    iterator end()
    {
        return iterator(data + 5);
    }

    int data[5];
};

std::size_t container::iterator::alive = 0;

struct cls
{
    container iterable;
};

void test_main(lua_State* L)
{
    using namespace luabind;

    module(L)
    [
        class_<cls>("cls")
          .def(constructor<>())
          .def_readonly("iterable", &cls::iterable, return_stl_iterator())
    ];

    DOSTRING(L,
        "x = cls()\n"
        "sum = 0\n"
        "for i in x.iterable do\n"
        "    sum = sum + i\n"
        "end\n"
        "assert(sum == 15)\n"
        "collectgarbage('collect')\n"
    );

    assert(container::iterator::alive == 0);
}

