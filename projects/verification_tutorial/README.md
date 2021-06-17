# Verifying designs written in Silice

> __Disclaimer:__ most tools refer to those techniques as “formal verification”.
> While this is not quite a false claim in our case (we are still trying to ensure correctness of our designs through the use of maths),
> we feel that there is some sort of “proof” connotation under this term.
> We believe that the features implemented are more under the “Property checking” theme, which itself is
> a subset of formal verification.
>
> Please also note that, if all your tests pass, this does not necessarily mean that your design is “proved” to be correct 
> at any time in any situation.
> For example, performing a BMC with a very low depth parameter may result in false-positives
> (e.g. no false assertion has been reached yet, therefore nothing is not correct, leading to a passing test).


## Table of contents

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Verifying designs written in Silice](#verifying-designs-written-in-silice)
    - [Table of contents](#table-of-contents)
    - [Prerequisites](#prerequisites)
        - [Verification methods](#verification-methods)
            - [Bounded Model Checking (BMC)](#bounded-model-checking-bmc)
            - [Temporal k-induction](#temporal-k-induction)
        - [Programs needed](#programs-needed)
    - [Easy verification with the formal board](#easy-verification-with-the-formal-board)
    - [Verifying designs, what to know and how to use](#verifying-designs-what-to-know-and-how-to-use)
        - [Algorithm modifiers for verification](#algorithm-modifiers-for-verification)
            - [The `#depth` modifier](#the-depth-modifier)
            - [The `#timeout` modifier](#the-timeout-modifier)
            - [Choosing which method to use with the `#mode` modifier](#choosing-which-method-to-use-with-the-mode-modifier)
        - [Assertions and assumptions](#assertions-and-assumptions)
        - [Stability checks](#stability-checks)
        - [State checking](#state-checking)
        - [Cover tests and trace generation](#cover-tests-and-trace-generation)
    - [Examples](#examples)

<!-- markdown-toc end -->


<!-- Symbiyosys, Yices2, Yosys, ABC and minimal knowledge -->
## Prerequisites

Getting started with design verification requires a bit of knowledge about the methods and programs that are used.
Please make sure that all the programs required are installed!

<!-- Explain: BMC, temporal induction (what it does + input parameters -- with interactive drawings) -->
### Verification methods

#### Bounded Model Checking (BMC)

A Bounded model Checking (or BMC for short) of depth `k` is a method trying to ensure that, for `i` going from `0` to `k - 1`,
if the state `i` is valid (where “valid” means that all assertions hold under all assumptions), then all of its successor states `i + 1`
must also be valid.

In other words: starting from a valid state does not drive us through an invalid state in `k` steps.

![bmc](./bmc.png)

#### Temporal k-induction

A temporal k-induction is the opposite of the spectrum compared to the BMC. It states that, for any valid state `s`,
it must be preceded by a sequence of maximum `k` valid states.

![k-induction](./tind.png)

### Programs needed

Symbiyosys is a front-end for Yosys to make formal verification easier.
As such, you will also need Yosys, which you can get [here](https://github.com/YosysHQ/yosys).
Note that, if you choose to build it yourself, you may need to create a symlink for yosys-abc,
depending on whether you installed it with yosys or on its own (because some programs expect a `yosys-abc` executable,
which isn't created if you have an external ABC solver).
You can get Symbiyosys [here](https://symbiyosys.readthedocs.io/en/latest/).

You will also need the SMT solver Yices2, which is available [here](https://yices.csl.sri.com/).
This solver handles BMC and cover tests quite fine, and fast enough (compared to e.g. z3).

<!-- Introduce the formal board, what it does, how it is useful -->
## Easy verification with the formal board

Because writing a `.sby` file to instruct symbiyosys to work correctly (together with some needed SMT constraints files)
is a pain, we chose to develop a Silice board in charge of generating every needed file and running Symbiyosys with correct parameters.

It also runs Symbiyosys in a minimal interface, because it generates *a lot* of logs.

If you feel brave enough, or feel like you missed something that the interface should have reported, you may dive into the full
log file named `logfile.txt` generated in the build folder.
Please note however that you may also have to dive into the Verilog code to fetch the correct positions in the Silice files.

In case you want to modify the file `formal.sby` (which is also generated), you will have to run Symbiyosys by hand
(re-running the formal board will override all your modifications) using the command `sby -f formal.sby`.
The `-f` option indicates that we are okay discarding the old results of previous runs.

<!-- Describe implemented features (#assert, #assume, #restrict, #cover, #wasat, #stable, #stableinput, #mode, #depth, #timeout, algorithm#) -->
## Verifying designs, what to know and how to use 

In this section, we will describe implemented features for design verification, through an interactive design example
that we will complete at each step.
Please note that an algorithm that can be verified is marked with a `#`, like `algorithm#`, and is necessarily output 
in the end design.
Because this behavior may not be correct (and can be space-consuming, even though most tools will optimize those away because
they are never instantiated), it is a good practice to surround those algorithms with `$$if FORMAL` blocks.
The `FORMAL` macro is automatically defined by the formal board, therefore you do not need to write `$$FORMAL=1` anywhere.

We will try to verify the following property on the unsigned 8-bit integer division implemented in [common/divint_std.ice](../common/divint_std.ice): `x ÷ x = 1`.
We can also verify [common/divint_any.ice](../common/divint_any.ice) with this algorithm but a simple `include` needs to be changed for this to work.
The base algorithm skeleton is this:
```c
$$div_width=8
$$div_unsigned=1
$include('../common/divint_std.ice')

// Having no `main` algorithm somehow breaks the compiler...
algorithm main(output uint8 leds) {}

$$if FORMAL then
algorithm# x_div_x_eq_1(input uint$div_width$ x) {
                   //   ^^^^^^^^^^^^^^^^^^^^^^^ We register `x` as an input so that Symbiyosys tries
                   //                           to find a value for it that breaks everything.
                   //                           We could also have marked a local variable as `(* anyconst *)`.
  div$div_width$ div;
  // Instantiate the division algorithm 
  uint$div_width$ result = uninitialized;
  
  (result) <- div <- (x, x);
  // Perform `x ÷ x` and store the output in `result`
}
$$end
```

### Algorithm modifiers for verification

Our algorithm skeleton looks great, but...it doesn't verify anything.
It just computes `x ÷ x` for any `x` it is given, and that's it.
The result is even discarded because it is put in a local variable declared at the beginning of the algorithm, which is therefore
not accessible outside of it.

But before trying to verify anything, we must sit down and study our algorithm:

- The standard division takes about 1 cycle per bit to complete, so about 8 cycles in our case;
- Our algorithm only performs this division for now, so it takes 2 more cycles (for the algorithm “call”) to complete;
- Because we will add some verifying code, this will take some more cycles (around 2 in this case, trust me);

All this information leads us to the fact that the algorithm `x_div_x_eq_1` takes about 12 cycles to fully complete.
It is usually a good idea to round up this value to the next 5, which gives 15 in this case.
This allows us to get an error margin on the number of cycles we computed (or guessed?).

> __Note:__ overestimating the number of cycles should not hurt the verification process, i.e. putting 20 instead of 15 does not break the verification.

Let's talk about what we call algorithm modifiers.

#### The `#depth` modifier

Obviously, we did not compute the number of cycles needed for the algorithm to complete for nothing.
Remember the `k` parameter for the BMC or the temporal induction?
This specific parameter can be specified on a per-algorithm basis using the `#depth` modifier.
When doing a cover test, it corresponds to the number of cycles to take in account.

The `#depth` modifier takes a single integer as an argument, and defaults to `30` if not specified.
In our case, the test algorithm can be changed to:
```c
$$div_width=8
$$div_unsigned=1
$include('../common/divint_std.ice')

// Having no `main` algorithm somehow breaks the compiler...
algorithm main(output uint8 leds) {}

$$if FORMAL then
algorithm# x_div_x_eq_1(input uint$div_width$ x) <#depth=15> {
                                             //   ^^^^^^^^^ 15 cycles, as said earlier
  div$div_width$ div;
  uint$div_width$ result = uninitialized;
  
  (result) <- div <- (x, x);
}
$$end
```

#### The `#timeout` modifier

<details><summary>Click me to reveal the spoiler (please don't)</summary>

> We don't need it for our algorithm because it takes less than the default timeout to complete (around 2-3 seconds for a depth of 15).

</details>

Sometimes, verifying an algorithm takes too much time because there are so much constraints and the solver struggles with them.
Or there is an infinite loop somewhere that a verification statement depends on, which may lead to complex constraints to solve.
Or you may even want to restrict the maximum time an algorithm is allowed to “run” for before failing.

In any case, it is needed to be able to customize the timeout also on a per-algorithm basis.
This is where the `#timeout` modifier comes in handy.
Just like the `#depth` modifier, it takes a single integer as argument to specify the solver timeout (in seconds),
and defaults to 120 if not specified.

> __Note:__ if your test algorithm times out, it *might* be a good idea to increase this parameter.
> However, sometimes the algorithm may take too much time to be verified, because of complex generated constraints.
> 
> In this case, you can either wait half a day (43,200 seconds if you ever need this value) hoping for the best, or convince yourself
> that it's alright and most probably is correct (else it would have failed already).
> Obviously nothing can be concluded from a timeout, so it is up to you to decide.

#### Choosing which method to use with the `#mode` modifier

There are multiple ways to verify an algorithm: a simple BMC, a temporal induction and/or a cover test.
All of these are not mutually exclusive (i.e. you may perform a BMC **and** a temporal induction).

Just as for other modifiers, it is possible to use the `#mode` modifiers to specify what methods are used to verify an algorithm.
It takes a `&` separated list of modes (either `bmc` to perform a BMC, `tind` for a temporal induction or `cover` for a cover test) as argument,
and transforms it in order to satisfy those predicates:

- There is at most one of each mode in the list (i.e. `#mode = bmc & bmc` is interpreted as `#mode = bmc`).
- Modes are sorted using the partial order `bmc ≺ tind ≺ cover`. 
  This ensures that tests are always run in the same order no matter what happens.
  
If not specified, the `#mode` modifier takes the singleton list `bmc` as a default argument.

Going back to our example, we would like to perform both a BMC and a temporal induction.
The code thus looks like this:
```c
$$div_width=8
$$div_unsigned=1
$include('../common/divint_std.ice')

// Having no `main` algorithm somehow breaks the compiler...
algorithm main(output uint8 leds) {}

$$if FORMAL then
algorithm# x_div_x_eq_1(input uint$div_width$ x)
  <#depth=15, #mode=bmc & tind> { 
         //   ^^^^^^^^^^^^^^^^ Perform a BMC and a temporal induction
  div$div_width$ div;
  uint$div_width$ result = uninitialized;
  
  (result) <- div <- (x, x);
}
$$end
```

### Assertions and assumptions

Great!
Now that we learned about all the available algorithm modifiers, it's time to verify that the division works correctly as expected.
Remember that we want to check that `x ÷ x = 1`.
This is an undeniable fact of modern mathematics (assuming `÷` is the integral division only returning the quotient, not the remainder;
else we would have had to write `x ÷ x = (q=1, r=0)`).

One way to ensure that a property holds at some point is by writing an immediate assertion.
Asserting a property simply means “if the property does not hold here (i.e. it evaluates to a false value), then please inform me of what went wrong”.
Immediate assertions are introduced using the `#assert(property)` construct, where `property` is any boolean expression
(or at least an expression reducing to either a true or false value).

For our algorithm, the goal is to check that `result` is `1` and nothing else.
Therefore, we can add an assertions at the end of the algorithm, like this:
```c
$$div_width=8
$$div_unsigned=1
$include('../common/divint_std.ice')

// Having no `main` algorithm somehow breaks the compiler...
algorithm main(output uint8 leds) {}

$$if FORMAL then
algorithm# x_div_x_eq_1(input uint$div_width$ x) <#depth=15, #mode=bmc & tind> {
  div$div_width$ div;
  uint$div_width$ result = uninitialized;
  
  (result) <- div <- (x, x);
  
  #assert(result == 1);
  // Please make sure that at this point `result` is equal to `1`
}
$$end
```

But what if `x = 0`?
Anything divided by `0` is supposed to be undefined (turns out that `0 ÷ 0 = 255` when executed using Icarus).

Luckily, the division algorithm already restricts this case to never happen using the `#restrict` construct.
But we would like to write great tests, and not necessarily rely on any external verification.
Because `x ÷ x = 1` only if `x ≠ 0`, we can provide the assumption that `x ≠ 0` in our test.
This makes so that Symbiyosys will not try to find counter-examples where `x = 0`.

An assumption, much like a restriction, is introduced in the same way an assertion is, replacing `assert` with respectively `assume` and `restrict`.
The only difference between an assumption and a restriction lies in this property:

> If any assertion depends on an assumption, use `#assume`, else use `#restrict`.

In our test algorithm, the assertion depends on the assumption that `x ≠ 0`, therefore it must be modified as follows:
```c
$$div_width=8
$$div_unsigned=1
$include('../common/divint_std.ice')

// Having no `main` algorithm somehow breaks the compiler...
algorithm main(output uint8 leds) {}

$$if FORMAL then
algorithm# x_div_x_eq_1(input uint$div_width$ x) <#depth=15, #mode=bmc & tind> {
  div$div_width$ div;
  uint$div_width$ result = uninitialized;
 
  #assume(x != 0);
  // Please don't consider states leading to `0 ÷ 0`...
 
  (result) <- div <- (x, x);
  
  #assert(result == 1);
}
$$end
```

### Stability checks

<details><summary>Click me to reveal the spoiler (please don't)</summary>

> Because we do not use `x` in any assertions, there is little to no risk that a concurrent value change breaks something.
> 
> When in doubt, always stabilize the inputs. 
> The only thing it costs is some characters in the source code.

</details>

Our verification algorithm works...but only if the value of the parameter `x` does not change while the algorithm is running
(which can happen, and in fact Symbiyosys will try to!).

To prevent this, there is a special construct equivalent to saying that an input is assumed to be stable (i.e. to not change).
If you did not already infer its namme, it is `#stableinput`.
Note that it only takes a single identifier as an argument, and works only if this identifier is bound to an `input` cell.

There is also a counterpart to *assert* the stability of an expression, where “stability” means that the expression is expected not to change in the current state 
(or always, if in an `always` block).

Let us now also assume the stability of our input variable `x`, by modifying the algorithm as follows:
```c
$$div_width=8
$$div_unsigned=1
$include('../common/divint_std.ice')

// Having no `main` algorithm somehow breaks the compiler...
algorithm main(output uint8 leds) {}

$$if FORMAL then
algorithm# x_div_x_eq_1(input uint$div_width$ x) <#depth=15, #mode=bmc & tind> {
  div$div_width$ div;
  uint$div_width$ result = uninitialized;

  #stableinput(x);
  // We really don't want `x` to change in the middle of the algorithm...
  #assume(x != 0);
 
  (result) <- div <- (x, x);
  
  #assert(result == 1);
}
$$end
```

### State checking

> *But where did I come from?*

<details><summary>Click me to reveal the spoiler (please don't)</summary>

> It doesn't quite make sens to verify this in our interactive example.
> Therefore, a dumb example will most likely be given, to illustrate how one may use `#wasin`.

</details>

It is sometimes useful to verify that an algorithm took the correct path, that is the state sequence is what should be expected.
A very simple (and dumb) example is this one:
```c
algorithm f() {
  uint8 cnt = uninitialized;
init:
  cnt = 0;
loop:
  while (cnt < 3) {
    cnt = cnt + 1;
  }
end:
  // we want to check the loop operated correctly and that 3 cycles before, we were in the `init` state.
}
```

The `#wasin(state, N)` construct can be used to verify such use case, by providing it with the name of the state that was expected
and the number of cycles to look back for (defaults to `1` if not specified).
The state given must have been declared in the scope using the state introduction construct (as above, where `loop:` introduces and names a state).

Instead of the comment at the end, we can write `#wasin(init, 3)` to verify the situation given.

> __Note:__ while the `#wasin` is accepted everywhere an instruction is expected (even in `always` blocks),
> it is most likely to always fail in an `always` block or when it isn't part of a specific state.

### Cover tests and trace generation

Cover tests are some specific kind of verification allowing to potentially debug situations by generating specific VCD traces,
according to some test.
While this may not be a huge feature, we believe that this is a nice one to have in case debugging a specific example is needed at some point.

Cover tests can be declared using the `#cover(condition)` statement, which takes the condition to satisfy.
If the cover statement is reached but the condition evaluates to a false value, then it is simply ignored.

Please be aware that an unreached `#cover` statement is considered a failure to satisfy the cover test, and is reported as such
by Symbiyosys and the formal board.

<!-- Some quick examples of verification -->
## Examples

This directory contains several example of verifying code, for different algorithms:

- [divint_verif.ice](./divint_verif.ice) verifies some properties of unsigned integral division (the division used can be replaced quite easily by modifying the `$include` statement at the top of the file)
- [mulint_verif.ice](./mulint_verif.ice) verifies some properties of integral multiplication

You can run the verification process using the provided [Makefile](./Makefile), by simply running the command
`make file`, where `file` is the file without the `.ice` extension you want to run the whole process on.
