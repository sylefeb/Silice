# Algorithm calls, bindings and timings

Here we explain how algorithms can be instantiated and called. This is an important topic
with direct implication on synchronization between parallel operations, and the max frequency of your design.

For these explanations let us assume an algorithm with *N* outputs and M *inputs* called respectively `out1 ... outN` and ` in1 ... inM`.

## Calls

A first way to use and call an algorithm is to use the call syntax. The algorithm is first instantiated as:

`Algo alg_inst;`

And then called as:

 `(out1,...,outN) <- alg_inst <- (in1,...,inM)`

This call is *synchronous*: we wait for the algorithm to terminate before getting its outputs. In fact, it can be decomposed in two parts:
- the async call `alg_inst <- (in1,...,inM)` which starts the algorithm,
- the join `(out1,...,outN) <- alg_inst` which waits for the output.

Between call and join the caller continues its operations. Also note that the async call does not introduce any cycle for the caller. The join, however, waits for as many cycles as necessary. Hence, a join in an instruction block makes it a non *one-cycle* block -- one implication, for instance, is that join cannot be used in an always block which has to be a one-cycle block.

Instead, test whether the algorithm is done using `isdone(alg_inst)`. This is a simple test and can therefore be used anywhere.

The join both waits for the algorithm to be done and read its outputs. However, it is also possible to read the outputs
of an algorithm at any time using the `alg_inst.out1` syntax. In such cases, it is of course your responsibility to know whether the outputs are valid when read.
Similarly, the inputs can be written using the `alg_inst.in1 = ...` syntax.

For these reasons, an algorithm instance can also be called without any parameter, e.g.: `() <- alg_inst <- ()`, and the same is true of separate async / join calls.

When called with `alg_inst <- (...)` it takes exactly one cycle for the algorithm to start. Upon termination, it takes one cycle for the caller to be notified. Thus, calling an algorithm that executes in exactly `C` cycles will take `C+2` cycles when called as `(...) <- alg_inst <- (...)`.

Note that input/output interfaces have to be bound: they cannot be passed in a call (see next).

## Bindings



## Mixing bindings and calls



## Timings and design max frequency