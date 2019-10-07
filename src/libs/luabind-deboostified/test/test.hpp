// Copyright (c) 2005 Daniel Wallin, Arvid Norberg

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

#ifndef TEST_050415_HPP
#define TEST_050415_HPP

#include <luabind/error.hpp>
#include <luabind/lua_include.hpp>
#include <string>

void report_failure(char const* str, char const* file, int line);

#define CAT2(a,b) a##b
#define CAT(a,b) CAT2(a,b)

#ifdef _MSC_VER
// There seem to be lifetime issues with global variables on VC
#define COUNTER_GUARD(type)
#else
#define COUNTER_GUARD(type) \
    struct CAT(type, _counter_guard) \
    { \
        ~CAT(type, _counter_guard()) \
        { \
            TEST_CHECK(counted_type<type>::count == 0); \
        } \
    } CAT(type, _guard)
#endif

#define TEST_REPORT_AUX(x, line, file) \
	report_failure(x, line, file)

#define TEST_CHECK(x) \
    if (!(x)) \
        TEST_REPORT_AUX("TEST_CHECK failed: \"" #x "\"", __FILE__, __LINE__)

#define TEST_ERROR(x) \
	TEST_REPORT_AUX((std::string("ERROR: \"") + x + "\"").c_str(), __FILE__, __LINE__)

#define TEST_NOTHROW(x) \
	try \
	{ \
		x; \
	} \
	catch (...) \
	{ \
		TEST_ERROR("Exception thrown: " #x); \
	}

void dostring(lua_State* L, char const* str);

template<class T>
struct counted_type
{
    static int count;
    
    counted_type()
    {
        ++count;
    }

    counted_type(counted_type const&)
    {
        ++count;
    }

    ~counted_type()
    {
        TEST_CHECK(--count >= 0);
    }
};

template<class T>
int counted_type<T>::count = 0;

#define DOSTRING_EXPECTED(state_, str, expected) \
{                                               \
    try                                         \
    {                                           \
        dostring(state_, str);                  \
    }                                           \
    catch (luabind::error const& e)             \
    {                                           \
		using namespace std;					\
		if (std::strcmp(e.what(),				\
			(char const*)expected))             \
        {                                       \
            TEST_ERROR(e.what());				\
        }                                       \
    }                                           \
    catch (std::string const& s)                \
    {                                           \
        if (s != expected)                      \
            TEST_ERROR(s.c_str());              \
    }                                           \
}

#define DOSTRING(state_, str)                   \
{                                               \
    try                                         \
    {                                           \
        dostring(state_, str);                  \
    }                                           \
    catch (luabind::error const& e)             \
    {                                           \
        TEST_ERROR(e.what());					\
    }                                           \
    catch (std::string const& s)                \
    {                                           \
        TEST_ERROR(s.c_str());                  \
    }                                           \
}

#endif // TEST_050415_HPP

