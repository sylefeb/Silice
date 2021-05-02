#!/bin/bash

rm build/code0.hex 2> /dev/null
./compile_c.sh $1 --nolibc
