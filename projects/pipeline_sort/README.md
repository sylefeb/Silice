# Pipelined sort (linear time)

A sort has to be n.log(n), right? Well, not if you can design a
pipelined architecture!

**Note:** This is a toy example demonstrating Silice pipelines, as
  well as Silice pre-processor for code generation.

## What this does

This algorithm is designed to sort a stream of *no more than* N values
as they come in. The sort is pipelined such that if N values are
received, they are sorted N cycles after the last one came in (linear
time!).

Of course there is no free lunch, and this comes at the cost of a
pipeline of depth N.  So beyond being a fun -- and hopefully
interesting -- example, this will only be useful in practice for
relatively small values of N. But such cases do occur in practice, and
this algorithm may come in handy.

## How to test

Run `make verilator` or `make icarus` (the latter will open gtkwave
with the simulated waves).

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

Now, let's have a look at [main.ice](main.ice).

The algorithm is built around a main while loop:
```c
  uint8 i = 0;
  while (i<$2*N$) {
     ...
  }
```
The pipeline is within the loop, and the loop iterates 2.N times to
ensure the pipeline is fully flushed at the end (N cycles after the
last value is inserted).

The syntax `$2*N$` is using the Lua preprocessor. Indeed N is a
preprocessor variable defined before with this line:
```c
$$N=16
```
Using `$$` at the start of a line indicates that the entire line is
preprocessor code, while using `$...$` within a line of code inserts
the preprocessor result within the current code line. So for instance
`$2*N$` becomes `32` when N=16.

This loop inserts (streams) the values from the `in_values` array into
the pipeline. For each iteration below N, a value is read from
`in_value` and placed in front of the pipeline top stage. For
iterations above N we insert the MAX value, which in our case is 255,
so that they no longer influence the result.

```c
to_insert = i < $N$ ? in_values[i] : 255;
```

Again, the last N iterations are only here to flush the pipeline,
ensuring the last inserted value can fully propagate ; with this
simple algorithm this requires N cycles.

From the point of view of a single pipeline stage things are fairly
simple.  Stage `$n$` is responsible for the value stored at rank n in
the sorted array, `sorted_$n$`. The variables `sorted_$n$` together
are the result array: At the end `sorted_0` contains the smallest
value and `sorted_$N-1$` the largest (we sort in ascending order). The
role of each pipeline stage is to maintain the value of `sorted_$n$`
given incoming values.

At each clock cycle each stage receives a value to be inserted,
`to_insert`. Each stage compares this incoming value to the value
currently in its `sorted_$n$`.  If the incoming value is larger,
nothing is changed and the value is passed further down the pipeline.
If the incoming value is smaller, it replaces the current value in
`sorted_$n$`, and the evicted value is passed to the next stage, for
further insertion: next cycle the evicted value becomes the one to
insert at stage n+1.  Let's have a look at the code for a single
stage:

```c
    if ( i > $n$                    // do nothing before the pipeline reached this stage
      && to_insert < sorted_$n$ ) { // if the value to insert is smaller, we insert here
        // the current value is evicted and becomes the next one to insert
        uint8 tmp  = uninitialized;
        tmp        = sorted_$n$;
        sorted_$n$ = to_insert;
        to_insert  = tmp;
    }
```

The really important thing here is that all stages execute in
parallel, such that the evicted values *trickle* down the pipeline all
together, at each clock cycle. There are, in fact, N versions of
`to_insert` at all times, one per stage. It takes N cycles to flush
the pipeline, as if the last inserted value is the largest one it has
to trickle down all N stages.

Now that we understand each stage, how do we tell Silice to build a
pipeline? The syntax is simply:
```c
{
  // stage 0
} -> {
  // stage 1
} -> {
  // final stage
}
```
Note how Silice takes care of ensuring that `to_insert` is passed from
one stage to another. In a Silice pipeline, as soon as a variable is
written it automatically trickles down the pipeline: it is passed from
one stage to another. Here, we capture `to_insert` in the pipeline in
the first stage, by writing it as:
```c
to_insert = i < $N$ ? in_values[i] : 255;
```

Please refer to the documentation for more details on pipelines
(*Note: this part of the documentation is not yet written ;)* ).

As our pipeline depth depends on the value of N, we build it with the
preprocessor:
```c
$$for n=0,N-1 do
    {
      // [removed] code for stage n
    }
$$if n < N-1 then
    -> // pipe to next stage (if not last)
$$end
$$end
```

And that's it! We have a linear time sorting algorithm for an incoming
stream of values.

## Example run

The following figure illustrates a run for N=3. It takes 6 cycles to
guarantee that the sort is fully terminated.

The figure shows 6 clock cycles from left to right. For each cycle, we
see the incoming stream value at the top, the comparisons of each
stage (vertically) and the values to insert trickling down the
pipeline (orange arrows). The horizontal green arrows show when a
value is changed in the sorted array.

For instance, consider the value `20`. Its insertion starts at cycle
2. Stage 0 pushed it down as it is greater than `5`, already inserted
there. On cycle 3, `20` evicts `MAX` and replaces it in the result
array. However, `1` started its insertion at cycle 3 and evicted
`5`. On cycle 4, `5` reaches stage 1 and evicts `20`. On cycle 5, in
stage 2, `20` evicts `MAX` and replaces it in the result array.

![pipeline sort](pipeline_sort.jpg)

## Further reading

For efficient sorting in parallel refer to
[sorting networks](https://en.wikipedia.org/wiki/Sorting_network).
Typical parallel algorithms are
[odd-even sort](https://en.wikipedia.org/wiki/Odd%E2%80%93even_sort)
and [bitonic sort](https://en.wikipedia.org/wiki/Bitonic_sorter).
