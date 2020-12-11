# Sorting in linear time

A sort has to be n.log(n), right? Well, not if you have an FPGA and a pipelined architecture!

## How to test

Run `make verilaotr` or `make icarus` (the latter will open gtkwave with the simulated waves).


## Principle

This is an example of a pipelined sort algorithm.

It runs in O(n) (2.n cycles for n entries).

![pipeline sort](pipeline_sort.jpg)
