#!/bin/bash

rm build/code1.hex 2> /dev/null
./compile_c.sh $1
