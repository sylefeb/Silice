/*

    Silice FPGA language and compiler
    Copyright 2019, (C) Sylvain Lefebvre and contributors

    List contributors with: git shortlog -n -s -- <filename>

    GPLv3 license, see LICENSE_GPLv3 in Silice repo root

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, either version 3 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <https://www.gnu.org/licenses/>.

(header_2_G)
*/
// -------------------------------------------------

// This contains extra definitions that are required for proper compilation
// with the WASI WebAssembly framework, due to lack of support for exceptions
// and threads (the later should not be needed, ANTLR is creating the missing
// __cxa_thread_atexit export)

#if defined(__wasi__)

// well ...
extern "C" {
void *  __cxa_allocate_exception(size_t /*thrown_size*/) { abort(); }
void    __cxa_throw(void */*thrown_object*/, std::type_info */*tinfo*/, void (*/*dest*/)(void *)) { abort(); }
int     system( const char* ) {}
clock_t clock() { return 0; }
FILE   *tmpfile() { return NULL; }
int     __cxa_thread_atexit(void*, void*, void*) {}
}

#endif

// -------------------------------------------------
