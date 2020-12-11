# Pipelined sort (linear time)

A sort has to be n.log(n), right? Well, not if you can design a pipelined architecture!

**Note:** This is a toy example demonstrating Silice pipelines, as well as Silice pre-processor for code generation.

## What this does

This algorithm is designed to sort a stream of values as they come in. The sort is pipelined such that
if N values are received, they are sorted after 2.N cycles (linear time!). Of course there is no free lunch, and this
comes at the cost of a pipeline of depth N. So beyond being a fun -- and hopefully interesting -- example, 
this will only be useful in practice for relatively small values of N. But such cases do occur in practice, and this
algorithm may come in handy.

## How to test

Run `make verilator` or `make icarus` (the latter will open gtkwave with the simulated waves).

You will see a list of sorted entries, such as:

```
[          0] =   1
[          1] =   4
[          2] =  45
[          3] =  50
[          4] =  78
[          5] =  89
[          6] = 122
[          7] = 131
[          8] = 144
[          9] = 149
[         10] = 181
[         11] = 190
[         12] = 206
[         13] = 209
[         14] = 219
[         15] = 228
```

## Walkthrough the code

Now, let's have a look at [main.ice](https://github.com/sylefeb/Silice/blob/wip/projects/pipeline_sort/main.ice).

The algorithm is built around a main while loop:
```c
  uint8 i = 0;
  while (i<$2*N$) {
     ...
  }
```
The pipeline is within the loop, and the iterates 2.N times to ensure the pipeline is fully flushed at the end.
The syntax `$2*N$` is using the Lua preprocessor, indeed N is a preprocessor variable defined before with this line:
```c
$$N=16
```
Using `$$` at the start of a line indicates that the entire line is preprocessor code, while using `$...$` within a line of 
code inserts the preprocessor result within the current code line. So for instance `$2*N$` becomes `32` when N=16.

This loop inserts (streams) the values from the `in_values` into the pipeline. For each iteration
below $N$, a value is read from `in_value` and placed in front of the pipeline top stage. For iterations
above $N$ we insert the MAX value, which in our case is 255, so that they no longer influence the result.

```c
to_insert_0 = i < $N$ ? in_values[i] : 255;
```

The last N iterations are only here to flush the pipeline, ensuring the last inserted value
can fully propagate ; with this simple algorithm this requires N cycles.

Now, let's have a look at a single pipeline stage. 

```c
  if (to_insert_$n$ < sorted_$n$) {  // if the value to insert is smaller, we insert here
    to_insert_$n+1$ = sorted_$n$;    // the current value is evicted and becomes the next one to insert
    sorted_$n$      = to_insert_$n$; // the current value is replace with the new one to insert here
  } else {
    to_insert_$n+1$ = to_insert_$n$; // otherwise, the value has to be inserted further
  }
```

Each stage `$n$` uses two variables: `to_insert_$n$` and `sorted_$n$`.
The variables `sorted_$n$` actually are the result array. At the end `sorted_0` contains the smallest value and
`sorted_$N-1$` the largest. The role of each pipeline stage is to compare the current value of `sorted_$n$`
with the incoming value of `to_insert_$n$`. If `to_insert_$n$` is smaller, then the value of `sorted_$n$` is evicted,
replaced by `to_insert_$n$`, and the evicted value becomes the one to insert at stage n+1: it is stored
in `to_insert_$n+1$`.

From the point of view of a single stage things are fairly simple. Stage $n$ is responsible for the value stored
at rank $n$ in the sorted array. The stage receives a value to insert. If it is smaller than the current one it inserts
it and ask further stages to insert the evictede value. If the recived value is larger, it is simply passed further down
the pipeline. 

The really interesting thing here is that all stages execute in parallel, such that the evicted values trickle down
the pipeline all together, at each clock cycle. It takes N cycles to flush the pipeline, as if the last inserted
value is the largest one it has to trickle down all N stages.

## Example run

The following figure illustrates a run for N=3. It takes 6 cycles to gaurantee the sort is fully
terminated. 

![pipeline sort](pipeline_sort.jpg)

## Further reading

For efficient sorting in parallel refer to [sorting networks](https://en.wikipedia.org/wiki/Sorting_network). 
Typical parallel algorithms are [odd-even sort](https://en.wikipedia.org/wiki/Odd%E2%80%93even_sort) and [bitonic sort](https://en.wikipedia.org/wiki/Bitonic_sorter). 
