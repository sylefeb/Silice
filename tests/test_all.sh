#!/bin/bash
IFS=$'\n'
tests=$(find -maxdepth 1 -name '*.si' -printf '%f\n' | sed 's/\.si$//1' | sort -u)
for i in $tests; do
  printf "%-30s" $i
  mkcmd="make $i";
  cmd_out=`eval $mkcmd 2>&1`
  has_err=$(echo $cmd_out | grep -i "error");
  if [ -z "$has_err" ];
  then
      printf " [COMPILED]\n"
  else
      printf " [ FAILED ]\n       %s\n" "$mkcmd"
  fi
done
