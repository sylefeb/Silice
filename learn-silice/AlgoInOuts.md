# Algorithm calls, bindings and timings

Here we explain how algorithms can be instantiated and called. This is an important topic with direct implication on synchronization between parallel operations, and the max frequency of your design.

Even if you are familiar with Silice call an binding syntax, make sure to read the [last section](#timings) on timing considerations.

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

For these reasons, an algorithm instance can also be called without any parameter on either side, e.g.: `() <- alg_inst <- ()` or `() <- alg_inst <- (in1,...,inM)` or  `(out1,...,outN) <- alg_inst <- ()`. The same is true of separate async / join calls.

When called with `alg_inst <- (...)` it takes one cycle for the algorithm to start. Upon termination, it takes one cycle for the caller to be notified. Thus, calling an algorithm that executes in exactly `C` cycles will take `C+2` cycles when called as `(...) <- alg_inst <- (...)`.

Note that input/output interfaces have to be bound: they cannot be passed in a call (see next).

## Bindings

Algorithms input and outputs can be bound upon algorithm instantiation (the same of true of imported Verilog modules).

All or only parts of the inputs and outputs may be bound.  However, once at least one *input* binding exists, the only way to call the algorithm is with empty parameter lists: `alg_inst <- ()`. The 'dot' syntax is no longer available for bound inputs. There is no impact on outputs.

## Timings
<a href="#timings"></a>

Here we discuss the different between using the `<:` and `<::` binding operators as well as using `output` and `output!` in an algorithm. Both relate to when the parent and instantiated algorithm see the changes in inputs and outputs. This has important implications for keeping things in sync, and also impact the generated circuit depth (critical path and max frequency).

To illustrate, let us use a simple example case:

```c
algorithm Algo(
  input  uint8 i,
  output uint8 v) // can be output or output!
{
  always {
    v = i;
  }
}

algorithm main(output uint8 leds)
{
  uint32 cycle = 0;

  Algo alg_inst(
    i <: cycle  // can use <: or <::
  );

  while (cycle != 16) {
    __display("[cycle %d] (main) alg_inst.v = %d",cycle,alg_inst.v);
    cycle = cycle + 1;
  }

}
```

There are four possible combinations in how the input `i` and output `o` can be written. The output can be either `output` or `output!` (immediate). The input can be bound using either `<:` (value as modified by current cycle) or `<::` (value as it was at cycle start).



### What about calls?

