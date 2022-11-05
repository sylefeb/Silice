#!/bin/bash
IFS=$'\n'
tests=$(find -maxdepth 1 -name '*.si' -printf '%f\n' | sed 's/\.si$//1' | sort -u)

task() {
  mkcmd="make $1 ARGS=\"--no_build\"";
  cmd_out=`eval $mkcmd 2>&1`
  has_err=$(echo $cmd_out | grep -i "error");
  if [ -z "$has_err" ];
  then
    printf "%-30s [   OK   ]\n" $1
  else
    printf "%-30s [ FAILED ]\n" $1
  fi
}

T=4
for i in $tests; do
  ((t=t%T)); ((t++==0)) && wait
  task $i &
done
