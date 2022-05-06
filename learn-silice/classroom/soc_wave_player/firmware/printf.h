// @sylefeb 2022
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

#pragma once

#include <stdarg.h>

extern void (*f_putchar)(int);

// everyone needs a printf!
int printf(const char *fmt,...);
