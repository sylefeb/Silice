# Silice
## *A language for hardcoding Algorithms into FPGA hardware*

This is the Silice main documentation.

When designing with Silice your code describes circuits. If not done already, it is highly recommended to [watch the introductory video](https://www.youtube.com/watch?v=_OhxEY72qxI) (youtube) to get more familiar with this notion and what it entails.

## Table of content

-   [A first example](#a-first-example)
-   [Terminology](#terminology)
-   [Basic language constructs](#basic-language-constructs)
    -   [Types](#types)
    -   [Constants](#constants)
    -   [Variables](#variables)
    -   [Tables](#tables)
    -   [Block RAMs / ROMs](#block-rams-roms)
    -   [Operators](#operators)
        -   [Swizzling](#swizzling)
        -   [Arithmetic, comparison, bit-wise, reduction,
            shift](#arithmetic-comparison-bit-wise-reduction-shift)
        -   [Concatenation](#concatenation)
        -   [Bindings](#bindings)
        -   [Always assign](#contassign)
        -   [Bound expressions](#exprtrack)
    -   [Groups](#groups)
    -   [Interfaces](#interfaces)
    -   [Bitfields](#bitfields)
    -   [Intrinsics](#intrinsics)
-   [Algorithms](#algorithms)
    -   [Declaration](#declaration)
    -   [Instantiation](#instantiation)
    -   [Call](#call)
    -   [Subroutines](#subroutines)
    -   [Circuitry](#circuitry)
    -   [Combinational loops](#combloops)
    -   [Always assignments](#always-assignments)
    -   [Always blocks](#always-blocks)
    -   [Clock and reset](#clock-and-reset)
    -   [Modifiers](#modifiers)
-   [Execution flow and cycle utilization rules](#execution-flow-and-cycle-utilization-rules)
    -   [The step operator](#the-step-operator)
    -   [Control flow](#control-flow)
    -   [Cycle costs of calls to algorithms and
        subroutines](#cycle-costs-of-calls-to-algorithms-and-subroutines)
    -   [Pipelining](#pipelining)
-   [Lua preprocessor](#lua-preprocessor)
    -   [Principle and syntax](#principle-and-syntax)
    -   [Includes](#includes)
    -   [Pre-processor image and palette
        functions](#pre-processor-image-and-palette-functions)
-   [Interoperability with Verilog
    modules](#interoperability-with-verilog-modules)
    -   [Append](#append)
    -   [Import](#import)
    -   [Wrapping](#wrapping)
-   [Host hardware frameworks](#host-hardware-frameworks)
    -   [VGA emulation](#vga-emulation)

GitHub repository: <https://github.com/sylefeb/Silice/>



# A first example

As a brief overview, let us consider a simple first example. It assumes two input/output signals: a `button` input (high when
pressed) and a `led` output, each one bit.

The *main* unit – the one expected as top level – simply asks the
led to turn on when the button is pressed. We will consider several
versions – all working – to demonstrate basic features of Silice.

Perhaps the most natural version for a programmer would be:

``` c
algorithm main(input uint1 button,output uint1 led) {
  while (1) {
    led = button;
  }
}
```

This sets `led` to the value of `button` every clock cycle. However, we
could instead specify a *always assignment* between led and button:

``` c
algorithm main(input uint1 button,output uint1 led) {
  led := button;
}
```
This makes `led` constantly track the value of `button`.
A very convenient feature is that the always assignment can be overridden
at some clock steps, for instance:

``` c
algorithm main(input uint1 button,output uint1 led) {
  led := 0;
  while (1) {
    if (button == 1) {
      led = 1;
    }
  }
}
```

Of course this last version is needlessly complicated (the previous one
was minimal), but it shows the principle: `led` is always assigned
0, but this will be overridden whenever the button is pressed. This is
useful to maintain an output to a value that must change only on some
specific event (e.g. producing a pulse).

This first example has an interesting subtlety. The `button` input, when it comes directly from an onboard button, is *asynchronous*. This means it can change at anytime, even during a clock cycle. That could lead to trouble with the logic that depends on it. To be safe, a better approach is to *register* the input button, this can be achieved as follows:

``` c
algorithm main(input uint1 button,output uint1 led) {
  led ::= button;
}
```

Using the `::=` syntax introduces a one cycle latency and inserts a flip-flop between the asynchronous input and whatever comes after. This won't change our results in this toy example but is generally important.

Finally, in all examples above we declared the unit as an algorithm. This is in fact a shortcut for the full syntax:

``` c
unit main(input uint1 button,output uint1 led) {
  algorithm {
    while (1) {
      led = button;
    }
  }
}
```

Units can contain other types of blocks in addition to an algorithm: *always* blocks. For instance, we could rewrite our example *without* an algorithm:

``` c
unit main(input uint1 button,output uint1 led) {
  always {
    led = button;
  }
}
```
This describes a stateless circuit, that always assigns `button` to `led`.

We can also combine algorithms and always blocks:

``` c
unit main(input uint1 button,output uint1 leds) {

  uint1 reg_button = 0;

  always_before {
    led = 0;
  }

  algorithm {
    while (1) { if (reg_button) { led = 1; } }
  }

  always_after {
    reg_button = button;
  }

}
```

This last version demonstrates all blocks: the `always_before` block is always assigning `0` to `led`, every cycle *before*  the current algorithm step ; the `algorithm` block runs an infinite loop assigning `1` to `led` if `reg_button` is set ; the `always_after` block tracks the asynchronous `button` input into a variable, with a one cycle latency since it is the last thing done every cycle *after* the current algorithm step.

# Terminology

Some terminology we use next:

-   **unit**: The basic building block of a Silice design.
-   **algorithm**: The part of a unit that describes an algorithm.
-   **One-cycle block**: A block of operations that require a single
    cycle (no loops, breaks, etc.).
-   **Combinational loop**: A circuit where a cyclic
    dependency exists. These lead to unstable hardware synthesis and
    have to be avoided.
-   **VIO**: A Variable, Input or Output.
-   **Host hardware framework**: The Verilog glue to the hardware meant
    to run the design. This can also be a glue to Icarus[1] or
    Verilator[2], both frameworks are provided.

# Basic language constructs

## Types

Silice supports signed and unsigned integers with a specified bit width:

- `int`N with N the bit-width, e.g. `int5`: signed integer.

- `uint`N with N the bit-width, e.g. `uint11`: unsigned integer.

Since this is hardware design, there is no overhead in using arbitrary widths (as opposed to only 8, 16, 32). In fact it is best to use as little as possible for your purpose since it minimizes the hardware logic size.

## Constants

Constants may be given directly as decimal based numbers (eg. `1234`),
or can be given with a specified bit width and base:

-   `3b0101`, 3 bits wide value 5.

-   `32hffff`, 32 bits wide value 65535.

-   `4d10`, 4 bits wide value 10.

Supported base identifiers are: `b` for binary, `h` for hexadecimal, `d`
for decimal. If the value does not fit the bit width, it is clamped.

It is recommended to always specify the size of your constants, as this helps hardware synthesis and can avoid some ambiguities leading to unexpected behaviors.

## Variables

Variables are declared with the following pattern:

-   `TYPE ID = VALUE;` initializes the variable with VALUE when the unit
    algorithm starts, or the unit comes out of reset if no algorithm is present.

-   `TYPE ID(VALUE);` initializes the variable with VALUE on configuration
    (every time the FPGA is configured, including power-up).

Above, `TYPE` is a type definition
(Section <a href="#types" data-reference-type="ref" data-reference="types">Types</a>),
`ID` a variable identifier (starting with a letter followed by
alphanumeric or underscores) and `VALUE` a constant
(Section <a href="#constants" data-reference-type="ref" data-reference="constants">Constants</a>).

The initializer is mandatory, and is always a simple constant (no
expressions), or the special value `uninitialized`. The later indicates
that the initialization can be skipped, reducing design size. This is
particularly interesting on brams/broms and register arrays.

## Tables

`intN tbl[M] = {...} `

Example: `int6 tbl[4] = {0,0,0,0};`

Table sizes have to be constant at compile time. The initializer is
mandatory and can be a string, in which case each letter becomes its
ASCII value, and the string is null terminated.

The table size `M` is optional (eg. `int4 tbl[]={1,2,3};` ) in which
case the size is automatically derived from the initializer (strings
have one additional implicit character: the null terminator).

If the table size is specified and the initializer is a shorter string,
the table is automatically padded with zeros. A longer string results in
an error.

If the table size is specified and the initializer – not a string – has
a different number of elements, an error occurs. However, if a smaller
number of elements is given the last element can be `pad(value)` in
which case the remainder of the table is filled with `value`.

Example: `int6 tbl[256] = {0,0,0,0,pad(255)};`

Example: `int6 tbl[256] = {pad(0)};`

The keyword `uninitialized` may be used to explicitly skip table
initialization, in which case the initial table state is unknown:
`int6 tbl[4] = uninitialized;`.

Similarly, the padding can be uninitialized:
`int6 tbl[256] = {0,0,0,0,pad(uninitialized)};`. In this case, only the
first part of the table will be initialized, the state of the other
values will be unknown.

Tables can also be initialized from file content, but only for specific bit-widths (currently 8 bits, 16 bits and 32 bits).

Example: `int32 tbl[256] = {file("data.img"), pad(0)};`

This loads as many as possible 32 bits values from file `data.img` and pads the rest with zeros.

## Block RAMs / ROMs

`bram intN tbl[M] = {...} `

Block RAMs are declared in a way similar to tables. Block RAMs map to
special FPGA blocks and avoid using FPGA LUTs to store data. However,
accessing a block RAM typically requires a one-cycle latency.

> **Important:** Block RAMs are only initialized when the FPGA is configured.

A block RAM variable has four members accessible with the ’dot’ syntax:
- `addr` the address being accessed,
- `wenable` set to 1 if writing, set to 0 if reading,
- `rdata` result of read,
-  `wdata` data to be written.

Here is an example of using a block RAM in Silice:

``` c
bram int8 table[4] = {42,43,44,45};
int8 a = 0;

table.wenable = 0; // read
table.addr    = 2; // third entry
++:                // wait on clock
a = table.rdata;   // now a == 44
```

The rules for initializers of BRAMs are the same as for tables.

#### Block ROMs

ROMs use a similar syntax, using `brom` instead of `bram`.

#### Dual-port RAMs

A dual-port block RAM has eight members accessible with the ’dot’
syntax:

- `addr0` the address being accessed on port 0,
- `wenable0` write enable on port 0,
- `rdata0` result of read on port 0,
- `wdata0` data to be written on port 0,
- `addr1` the address being accessed on port 1
- `wenable1` write enable on port 1,
- `rdata1` result of read on port 1,
- `wdata1` data to be written on port1.

The dual-port BRAM also has optional clock parameters for port0 and
port1.

Here is an example of using a block RAM in Silice with different clocks:

``` c
dualport_bram int8 table<@clock0,@clock1>[4] = {42,43,44,45};
```

## Operators

### Swizzling

``` c
int6 a = 0;
int1 b = a[1,1]; // second bit
int2 c = a[1,2]; // int2 with second and third bits
int3 d = a[2,3]; // int3 with third, fourth and fifth bits
```

The first entry may be an expression, the second has to be a constant.

### Arithmetic, comparison, bit-wise, reduction, shift

All standard Verilog operators are supported, binary and unary.

### Concatenation

Concatenation allows to combine expressions to form expressions having
larger bit-width. The syntax is to form a comma separated list enclosed
by braces. Example:

``` c
  int6  i = 6b111000;
  int2  j = 2b10;
  int10 k = 0;
  k = {j,i,2b11};
```

Here c is obtained by concatenating a,b and the constant 2b11 to form a
ten bits wide integer.

Bits can also be replicated with a syntax similar to Verilog:

``` c
  uint2  a = 2b10;
  uint9  c = 0;
  c = { 1b0, {8{a[1,1]}} };
```

Here the last eight bits of variable c are set to the second bit of a.

### Bindings

Silice defines operators for bindings the input/output of units and
modules:

-   `<:` binds right to left,
-   `:>` binds left to right,
-   `<:>` binds both ways.

The bound sides have to be VIO identifiers. To bind expressions you can
use expression trackers (see
Section <a href="#expression-trackers" data-reference-type="ref" data-reference="expression-trackers">Expression trackers</a>).

Bound VIOs are connected and immediately track each others values. A
good way to think of this is as a physical wire between IC pins, where
each VIO is a pin. Bindings are specified when instantiating units
and modules.

The bidirectional binding is reserved for two use cases:

-  binding `inout` variables,
-  binding groups (see
    Section <a href="#groups">groups</a>)
    and interfaces (see
    Section <a href="#interfaces">interfaces</a>).

There are two other versions of the binding operators:

-   `<::` binds right to left, introducing a one cycle latency in the input value change,

-   `<::>` binds an IO group, introducing a one cycle latency in the inputs value change.

> The `<::` operators are *very important*: they allow to relax timing constraints (reach higher frequencies), by accepting a one cycle latency. As a general rule, using delayed operators (indicated by `::`) is recommended whenever possible.

Normally, the bound inputs are tracking the value of the bound VIO as it is changed during the current clock cycle. Therefore, the tracking unit/module immediately gets new values (in other words, there is a direct connection).
This, however, produces deeper circuits and can reduce the max frequency of a design. The delayed operators (indicated by `::`) allow to bind the value with a one cycle latency, placing a register (flip-flop) in between. This makes the resulting circuit less deep. See also the [notes on algorithms calls, bindings and timings](AlgoInOuts.md).

> **Note:** when a VIO is bound both to an instanced unit input and an instanced unit output (making a direct connection between two instantiated units), then using `<::` or `<:` will result in the same behavior, which is controlled by the use of `output` or `output!` on the algorithm driving the output. Silice will issue a warning if using `<::` in that case.

### Expression trackers

Variables can be defined to constantly track the value of an expression,
hence *binding the variable* and the expression. This is done during the
variable declaration, using either the *&lt;:* or *&lt;::* binding
operators. Example:

```c
algorithm adder(
  output uint9 o,
  // ...
) {
  uint8 a = 1;
  uint8 b = 2;
  uint9 a_plus_b <: a + b;

  a = 15;
  b = 3;
  o = a_plus_b; // line 11
}
```

In this case *o* gets assigned 15+3 on line 11, as it tracks immediate
changes to the expression *a+b*. Note that the variable *a\_plus\_b*
becomes read only (in Verilog terms, this is now a wire). We call *o* an
expression tracker.

The second operator, `<::` tracks the expression with a one cycle latency. Thus, its value is the value of the expression at the previous cycle. If used
in this example, o would be assigned 1+2.

> The `<::` operator is *very important*: it allows to relax timing constraints (reach higher frequencies), by accepting a one cycle latency. As a general rule, using delayed operators (indicated by `::`) is recommended whenever possible.

Expression trackers can refer to other trackers. Note that when mixing  `<:` and `<::` the second operator (`<::`) will not change the behavior of the first tracker. Silice will issue a warning in that situation, which can be silenced by adding a `:` in front of the first tracker, example:

```c
  uint9 a_plus_b        <:  a + b;
  uint9 c_plus_a_plus_b <:: c + a_plus_b;
```

The warning says:
```
[deprecated] (E:/cygwin64/home/sylefeb/Silice/tests/doc1.si, line    8)
             Tracker 'a_plus_b' was defined with <: and is used in tracker 'c_plus_a_plus_b' defined with <::
             This has no effect on 'a_plus_b'.
             Double check meaning and use ':a_plus_b' instead of just 'a_plus_b' to confirm.
```

> It is a *deprecation* warning since Silice previously accepted this syntax silently.

To fix this warning we indicate explicitly that we understand the behavior, adding `:` in front of `a_plus_b`:

```c
  uint9 a_plus_b        <:  a + b;
  uint9 c_plus_a_plus_b <:: c + :a_plus_b;
```

What happens now is that the value of `c_plus_a_plus_b` is using the immediate value of `a_plus_b` and the delayed value of `c` (from previous cycle).

# Units and algorithms

Units and algorithms are the main elements of a Silice design.
A unit is not an actual piece of hardware but rather a specification,
a blueprint of a circuit implementation.
Thus, units have to be *instantiated* before being used. Each instance
will be allocated physical resources on the hardware implementation,
using logical cells in an FPGA grid or transistors in an ASIC. Instances
are physically connected to other instances and IO pins by wires.

A unit may be instantiated several times, for example creating several CPUs within a same design. A unit can instantiate other units: [a small computer unit](../projects/ice-v/SOCs/ice-v-soc.si) would instantiate a memory, a CPU, a video signal generator and describe how they are connected together. When a unit is instantiated, all its sub-units are also instantiated.  In the following, we call the unit containing sub-units the *parent* of the sub-unit.

Instantiated units *always run in parallel*: they are pieces of hardware that are always powered on and active. Each unit be driven from a specific
clock and reset signal.

A unit can contain different types of hardware descriptions: a single `always` block, or an `algorithm` and its accompanying (optional) `always_before` and `always_after` blocks.

A unit containing only an algorithm block can be optionally directly declared as an algorithm, that is:
```verilog
unit foo( ... )
{
  algorithm {
    ...
  }
}
```
can equivalently be declared as:
```verilog
algorithm foo( ... )
{
  ...
}
```

### main (design 'entry point').

The top level unit is called *main*, and has to be defined in a standalone design. It is automatically instantiated by the *host hardware framework*, see
Section <a href="#host-hardware-frameworks">host hardware frameworks</a>.

## Unit declaration

A unit is declared as follows:

```verilog
unit ID (
(input | output | output! | inout) TYPE ID,
...
) <MODS> {
  DECLARATIONS
  ALWAYS_ASSIGNMENTS
  (ALWAYS_BEFORE_BLOCK ALGORITHM ALWAYS_AFTER_BLOCK) or (ALWAYS_BLOCK)
}
```

The algorithm block is declared as:
``` verilog
algorithm <MODS> {
  DECLARATIONS
  SUBROUTINES
  INSTRUCTIONS
}
```

Most elements are optional: the number of inputs and outputs can vary,
the modifiers may be empty (in which case the `’<>’` is not necessary),
declarations and instructions may all be empty.

Here is a simple example:

``` c
unit adder(input uint8 a,input uint8 b,output uint8 v)
{
  v := a + b;
}
```

Let us now discuss each element of the declaration.

#### *Inputs and outputs.*

Inputs and outputs may be declared in any order, however the order
matters when calling the algorithms (parameters are given in the order
of inputs, results are read back in the order of outputs). Input and
outputs can be single variables or tables. A third type `inout` exists, which represent tristate variables. These are groups with members `.oenable` (enables the output), `.o` for the output and `.i` for the input. See [this example project](../projects/inout/README.md) for details.

Note that there are two types of outputs: `output` and `output!`. These
distinguish between a *registered* and an *immediate* output (with exclamation
mark). This is a very important distinction when outputs are bound, but makes no difference when algorithms are called.

When using a registered output, the parent will only see the value updated at the next clock cycle. In contrast, an immediate output is a direct connection and ensures that the parent sees the results immediately, within the same cycle. This can be for instance important when implementing a video
driver; e.g. a HDMI module generates a pixel coordinate on its output
and expects to see the corresponding color on its input within the same
clock cycle (even though a better design would allow a one-cycle
latency). In such a scenario the algorithm outputting the color to the
HDMI driver will input the coordinate and use `output!` for the color.
However, using only `output!` has drawbacks. It tends to generate deeper circuits with lower maximum frequency. Oftentimes, paying one in latency
allow to reach higher frequencies and is well worth it.
Using `output!` may also result in combinational loops: a cycle in the described circuitry (that is generally bad). Silice detects such cases and issues an error (see also Section <a href="#combloops" data-reference-type="ref" data-reference="combloops">4.6</a>).

This is an important topic, and while this can be put aside when starting, mastering hardware design requires a deep understanding of the effect of registered inputs/outputs. Please refer to the [notes on algorithms calls, bindings and timings](AlgoInOuts.md) for more details.

> **Note:** Silice combinational loop detection is not perfect yet.
Such a problem would typically result in simulation hanging (unable to stabilize the circuit) with Verilator issuing a `UNOPTFLAT` warning.

#### *Declarations.*

Variables, instanced algorithms and instanced modules have to be
declared first (in any order). A simple example:

``` c
algorithm main(output uint8 led)
{
  uint8 r = 0;
  adder ad1;

  // ... btw this is a comment
}
```

#### *Always assign.*

Silice defines operators for *always assignment* of VIOs. An always
assignment is performed regardless of the execution state. It is applied
before any other logic and thus can be overridden from the always blocks and algorithm. Always assignments are order *dependent* between them.
The left side of the assignment has to be a VIO identifier, while the right side may be any expression. There are two variants:

-   `:=` always assign.

-   `::=` *registered* always assign.

The registered version introduces a register in between the right expression and the left VIO, and hence a one cycle latency to the assignment. This is convenient (and important) when assigning from an asynchronous input (e.g. an input pin) or when crossing clock domains.

Always assignments are specified just after variable declarations
and algorithms/modules instantiations. A typical use case is to make
something pulse high, for instance:

``` c
algorithm writer(
  output uint1 write, // pulse high to write
  output uint8 data,  // byte to write
  // ...
) {

  write := 0; // maintain low with always assign
  // ...
  if (do_write) {
    data  = ...;
    write = 1; // pulses high on next clock cycle
  }

}
```

> **Note:** The assignment is applied before any other logic. Thus, if the value of the expression in the right hand side is later changing (during the same clock cycle), this will not change the value of the left hand side. To track a value use an *expression tracker*.

> **Note:** It is highly recommended to register all asynchronous inputs using a variable that is always assigned the input with the registered always assignment `::=`.

> **Note:** (advanced) An always assignment is in itself asynchronous, thus it can be used to pass around asynchronous inputs or clocks.

## Instantiation

Units and imported modules can be instantiated from within a parent unit.
Optionally parameters can be *bound* to the parent unit variables (VIOs).
Instantiation uses the following syntax:

``` verilog
UNIT_NAME ID<@CLOCK,!RESET,...> (
BINDINGS
(<:auto:>)
);
```

where `UNIT_NAME` is the name of the unit to instantiate, `ID` a name identifier for the instance, and `BINDINGS` a comma separated list of bindings
between the instance inputs/outputs and the parent algorithm variables.
The bindings are optional and may be partial. `@CLOCK` optionally
specifies a clock signal, `!RESET` a reset signal, where `CLOCK` and
`RESET` have to be `uint1` variables in the parent algorithm. Both are
optional, and if none is specified the brackets `<>` can be skipped.
When none are specified the parent `clock` and `reset` are used for the
instance.

Other possible modifiers are:
- `reginputs`, applies only to non-callable units (units without an algorithm, or units which algorithm have an `<autostart>` modifier). This modifier requests inputs accessed with the dot syntax
to be registered, e.g. there will be a one cycle latency between their
assignment and when the instanced algorithm sees the change. Please refer to the [notes on algorithms calls, bindings and timings](AlgoInOuts.md) for details.


Each binding is defined as: `ID_left OP ID_right` where `ID_left` is the
identifier of an instance input or output, `OP` a binding operator
(Section <a href="#sec:bindings" data-reference-type="ref" data-reference="sec:bindings">3.6.4</a>)
and `ID_right` a variable identifier.

Combined with `autorun` such bindings allow to instantiate and
immediately run a unit to drive some of the parent unit
variables. Here is an example:

``` c
algorithm blink(output int1 fast,output int1 slow) <autorun>
{
  uint20 counter = 0;
  while (1) {
    counter = counter + 1;
    if (counter[0,8] == 0) {
      fast = ~fast;
    }
    if (counter == 0) {
      slow = ~slow;
    }
  }
}

unit main(output int8 leds)
{
  blink b(
    slow :> leds[0,1],
    fast :> leds[1,1]
  );

  always { __display("leds = %b",leds[0,2]); }    // forever, blink runs in parallel
}
```

In this example, algorithm `blink` is instanced as `b` in the main unit. It starts running immediately due to the `autorun` modifier in the declaration of `blink`.
The lower bits of `leds` are bound to the `slow` and `fast` outputs of `b`.
The main unit contains only an `always` block that runs forever. `__display` is used only in simulation and prints the value of `leds`.
Since all updates in `main` are done through bindings and always assignments,
and because *units run in parallel*, there is nothing else to do and `main` runs forever (as long as there is power).

#### Automatic binding.

The optional `<:auto:>` tag allows to automatically bind matching
identifiers: the compiler finds all valid left/right identifier pairs
having the same name and binds them directly. While this is convenient
when many bindings are repeated and passed around, it is recommended to
use groups for brevity and make all bindings explicit.

> **Note:** Automatic binding can be convenient, but is discouraged as it relies a name matching and changes can introduce silent errors. When a large number of inputs/outputs have to be bound, consider using groups and interfaces.

#### Direct access to inputs and outputs.

The inputs and outputs of instanced units *that are not bound*, can be
directly accessed using a ’dot’ notation. Outputs can be read and inputs
written to. Example:

``` c
algorithm algo(input uint8 i,output uint o)
{
  o = i;
}

algorithm main(output uint8 led)
{
  algo a;
  a.i = 131; // dot syntax access to input i of a
  () <- a <- (); // this is a call without explicit inputs/outputs
  led = a.o; // dot syntax access to output o of a
}
```

> **Note:** The dot syntax defaults to non registered inputs. This can be controlled by using the `<reginputs>` modifier when instantiating the unit.

## Call

Algorithms may be called synchronously or asynchronously, with or
without parameters. Only instanced algorithms may be called.

See also the detailed [notes on algorithms calls, bindings and timings](AlgoInOuts.md).

The asynchronous call syntax is as follows:

``` verilog
ID <- (P_1,...,P_N); // with parameters
ID <- (); // without parameters
```

Where `ID` is the instanced algorithm name. When the call is made with
parameters, all have to be specified. The parameters are given in the
same order they are declared in the algorithm being called. The call
without parameters is typically used when inputs are bound or specified
directly. Note that when parameters are bound, only the call without
parameters is possible.

When an asynchronous call is made, the instanced algorithm will start
processing at the next clock cycle. The algorithm runs in parallel to
the caller and any other instanced algorithm. To wait and obtain the
result, the join syntax is used:

``` verilog
(V_1,...,V_N) <- ID; // with receiving variables
() <- ID; // without receiving variables
```

> **Note:** Calling algorithms across clock domains is not yet supported. For such cases, autorun with bindings is recommended.

## Subroutines

Algorithms can contain subroutines. These are local routines that can be
called by the algorithm multiple times. A subroutine takes parameters,
and has access to the variables, instanced algorithms and instanced
modules of the parent algorithm – however access permissions have to be
explicitly given. Subroutines offer a simple mechanism to allow for the
equivalent of local functions, without having to wire all the parent
algorithm context into another module/algorithm. Subroutines can also
declare local variables, visible only to their scope. Subroutines avoid
duplicating a same functionality over and over, as their code is
synthesized a single time in the design, regardless of the number of
times they are called.

A subroutine is declared as:

``` verilog
subroutine ID(
input TYPE ID
...
output TYPE ID
...
reads ID
...
writes ID
...
readwrites ID
...
calls ID
) {
  DECLARATIONS
  INSTRUCTIONS
  return;
}
```

(a final return is optional)

Here are simple examples:

``` c
algorithm main(output uint8 led)
{
  uint8  a       = 1;

  subroutine shift_led(readwrites a) {
    a = a << 1;
    if (a == 0) {
      a = 1;
    }
  }

  subroutine wait() {
    uint20 counter = 0;
    while (counter != 0) {
      counter = counter + 1;
    }
  }

  led := a;

  while(1) {
    () <- wait <- ();
    () <- shift_led <- ();
  }
}
```

*Subroutines permissions.* Subroutine permissions ensure only those
variables given read/write permission can be manipulated. This mitigates
the fact that a subroutine may directly manipulate variables in the
parent algorithm. The format for the permissions is a comma separated
list using keywords `reads`, `writes`, `readwrites`


*Why subroutines?* There is a fundamental difference between a
subroutine and an algorithm called from a host: the subroutine never
executes in parallel, while a child algorithm could. However, if this
parallelism is not necessary, subroutines offer a simple mechanism to
repeat internal tasks.
 

*Global subroutines.* Subroutines may be declared outside of an
algorithm. Such subroutines are called *global* and may be called from
any algorithm. This is convenient to share subroutines across
algorithms. If a global subroutine requests access to parent algorithm
variables (read/write permissions), an algorithm calling the subroutine
has to have a matching set of variables in its scope. Note that global
subroutines are not technically shared, but rather copied in each
calling algorithm’s scope at compile time.

*Nested calls*

Subroutines can call other subroutines, and have to declare this is the
case using the keyword `calls`.

``` c
subroutine wait(input uint24 delay)
{
  // ...
}
subroutine init_device(calls wait)
{
  // ...
  () <- wait <- (1023);
}
```

Note that re-entrant calls (subroutine calling itself, even through
other subroutines) are not possible.

## Circuitry

Sometimes, it is useful to write a generic piece of code that can be
instantiated within a design. Such an example is a piece of circuitry to
write into an SDRAM, which bit width may not ne known in advance.

A circuitry offers exactly this mechanism in Silice. It is declared as:

``` verilog
circuitry ID(
input ID
output ID
inout ID
) {
INSTRUCTIONS
}
```

Note that there is no type specification on inputs/outputs as these are
resolved during instantiation. Here is an example of circuitry:

``` verilog
circuitry writeData(inout sd,input addr,input data) {
  // wait for sdram to not be busy
  while (sd.busy) { /*waiting*/ }
  // write!
  sd.data_in      = rdata;
  sd.addr         = addr;
  sd.in_valid     = 1;
}
```

Note the use of inout for sd (which is a group, see
Section <a href="#groups">groups</a>).
A circuitry is not called, it is instantiated. This means that every
instantiation is indeed a duplication of the circuitry.

Here is the syntax for instantiation:

``` verilog
(output_0,...,output_N) = ID(input_0,...input_N)
```

As for algorithms and subroutines, inputs and outputs have to appear in
the order of declaration in the lists. An inout appears twice, both as
output and input. Following the previous example here is the
instantiation from an algorithm:

``` verilog
(sd) = writeData(sd,myaddr,abyte);
```

> **Note:** currently circuitry instantiation can only be made on VIO identifiers
(no expressions, no bit-select or part-select). This restriction will be removed
at some point. In the meantime expression trackers provide a work around, first
defining a tracker with an identifier then giving it to the circuitry
(these can be defined in a block around the circuit instantiation).

## Combinational loops

When writing code, you may encounter a case where the Silice compiler
raises an error due to an expression leading to a combinational loop.
This indicates that the sequence of operations is leading to a cyclic
dependency in the circuit being described. These are in most cases
undesirable as they lead to unpredictable hardware behaviors.

A trivial solution is such a situation is to split the circuit loop
using the *step* operator (see
Section <a href="#sec:step" data-reference-type="ref" data-reference="sec:step">5.1</a>).
However, this will change you sequence of operations and the designer
may choose a different approach. Therefore Silice reports and error and
invites to either manually add a step, or to revise the code. In many
cases a slight rewrite avoids the issue entirely.

Example of a combinational loop:

``` c
algorithm main()
{
  uint8 a = 0;
  uint8 b = 0;
  // ...
  a = b + 1;
  a = a + 1; // triggers a combinational loop error
}
```

So what happens? It might seem that `a = a + 1` is the problem here, as
it writes as a cyclic dependency. In fact, that is not the sole cause.
On its own, this expression is perfectly fine: for each variable Silice
tracks to versions, the value at the cycle start and the value being modified (corresponding to a hardware flip-flip DQ pair). So `a = a + 1` in fact means
*a*<sub>current</sub> = *a*<sub>previous</sub> + 1. In fact, the code describes the circuit to update *a*<sub>previous</sub> from *a*<sub>current</sub>.

The problem here comes from the prior assignment to *a*, `a = b + 1`.
This already sets a new value for *a*<sub>current</sub>, and thus the next expression
`a = a + 1` would have to use this new value. This now leads to
*a*<sub>current</sub> = *a*<sub>current</sub> + 1
which this time is a combinational loop: a circuit that forms a closed loop.

A possible solution is to insert a cycle in between:

``` c
a = b + 1;
++: // wait one cycle
a = a + 1; // now this is fine
```

Another is to rewrite as (!):
``` c
a = b + 2;
```

> **Note:** Silice does not attempt to fix loops on its own, even in such simple cases. This may change in the future. However Silice has a gold rule to *never* introduce cycles or flip-flops that could not be predicted by the designer.

It would be difficult to manually keep track of all potential
chains, especially as they can occur through bindings, which is why Silice does it for you! In practice, such loops are
rarely encountered, and in most cases easily resolved with slight
changes to arithmetic and logic.

> **Note:** Silice combinational loop detection is not perfect yet. Such a problem would typically result in simulation hanging (unable to stabilize the circuit) with Verilator issuing a `UNOPTFLAT` warning.

## Always assignments

After declarations, optional always assignments can be specified. These
use the operators defined in
Section <a href="#sec:contassign" data-reference-type="ref" data-reference="sec:contassign">3.6.5</a>.
Always assignments allow to follow the value of an expression in a
variable, output, or instanced algorithm input or output. Contrary to
expression trackers
(Section <a href="#sec:exprtrack" data-reference-type="ref" data-reference="sec:exprtrack">3.6.6</a>),
the assigned values can be changed during a cycle.

Example:

``` c
algorithm main(output uint8 led)
{
  uint8 r = 0;
  adder ad1;

  led   := r;
  ad1.a := 1;
}
```

These assignments are always performed, before anything else in the algorithm.
They are order dependent. For instance:

``` c
b := a;
c := b;
```

is not the same as:

``` c
c := b;
b := a;
```

In the first case, c will immediately take the value of a, while in the
second case c will take the value of a after one clock cycle. This is
useful, for instance, when crossing a clock domain as it allows to
implement a two stages flip-flop. In fact, Silice provides a shortcut
for exactly this purpose, making the temporary variable b unnecessary:

``` c
c ::= a;
```

## Always blocks

Algorithms can have two always blocks: `always_before` (or `always`) and
`always_after`. An always block has to be single cycle (no goto, while
or step operator inside). It is always running, regardless of the state
of the rest of the algorithm. The `always_before` block is executed
immediately after always assignments, and before anything else. The
`always_after` block is executed after everything else.

The syntax simply is:

``` c
always_before {
  // instructions
  // ...
}
```

Assigning a variable in an always before block or using an always
assignment is in fact equivalent, that is:

``` c
always_before {
  a = 0;
}
```

is functionally the same as

``` c
a := 0;
```

*Note:* variables changed in `always_after` blocks have to use on configuration-time
initialization only (e.g. `uint8 v(0)`).

## Clock and reset

All algorithms receive a `clock` and `reset` signal from their parent
algorithm. These are intrinsic variables, are always defined within the
scope of an algorithm and have type `int1`. The clock and reset can be
explicitly specified when an algorithm is instanced
(Section <a href="#sec:instantiation" data-reference-type="ref" data-reference="sec:instantiation">4.2</a>).

## Modifiers

Upon declaration, modifiers can be specified (see `<MODS>`) in the
declaration). This is a comma separated list of any of the following:

-   **Autorun.** Adding the `autorun` keyword will ask the compiler to
    run the algorithm upon instantiation, without waiting for an
    explicit call. Autorun algorithms cannot be called.

-   **Internal clock.** Adding a `@ID` specifies the use of an
    internally generated clock signal. It is then expected that the
    algorithm contains a `int1 ID = 0;` variable declaration, which is
    bound to the output of a module producing a clock signal. This is
    meant to be used together with Verilog PLLs, to produce new clock
    signals. The module producing the new clock will typically take
    `clock` as input and `ID` as output.

-   **Internal reset.** Adding a `!ID` specifies the use of an
    internally generated reset signal. It is then expected that the
    algorithm contains a `int1 ID = 0;` variable declaration, which is
    bound to the output of a module producing a reset signal. This may
    be used, for instance, to filter the signal from a physical reset
    button.

-   **One-hot.** Adding the `onehot` modifier will use a ’onehot’ state
    numbering for the algorithm state machine. On small algorithms with
    few states this can result in smaller, faster designs.

Here is an example:

``` c
  algorithm main(output int1 b) <autorun,@new_clock>
  {
    int1 new_clock = 0;

    my_pll pll(
      base_clock <: clock,
      gen_clock :> new_clock
    );

    // the main algorithm is sequenced by new_clock
    // ...
  }
```

Which signals are allowed as clocks and resets depends on the FPGA
architecture and vendor toolchain.

# Execution flow and cycle utilization rules

Upon compilation, Silice breaks down the code into a finite state
machine (FSM). Each state corresponds to a circuit that updates the variables
within a single cycle, and selects the next state.
We next call these circuits *combinational chains*.

Silice attempts to form the longest combinational chains, or equivalently
to minimize the number of states in the FSM. That is because going from one
state to the next requires one clock cycle, delaying further computations.
Of course, longer combinational chains also lead to reduced clock frequency,
so there is a tradeoff. This is why Silice lets you explicitly specify
where to cut a combinational chain using the step operator `++:`

Note that if a state contains several independent combinational chain,
they will execute as parallel circuits (e.g. two computations regarding
different sets of variables). Grouping such computations in a same state
increases parallelism, without deepening the combinational chains.

The use of control flow structures such as `while` (or `goto`), as well
as synchronization with other algorithm also require introducing states.
This results in additional cycles being introduced. Silice follows a set
of precise rules to do this, so you always know what to expect.

## The step operator

Placing a `++:` in the sequence of operations of an algorithm explicitly
asks Silice to wait for exactly one cycle at this precise location in
the execution flow. Each next `++:` waits one additional cycle.

This has several important applications such as waiting for a memory
read/write, or breaking down long combinational chains that would
violate timing.

## Control flow

The most basic control flow operation is `goto`. While it may be used
directly, it is recommended to prefer higher level primitives such as
`while` and subroutines, because `goto` often leads to harder to read
and maintain code[3]. Yet, they are a fundamental low-level operation
and Silice is happy to expose them for your enjoyment!

`goto` always requires one cycle to ’jump’: this is a change of state in
the FSM. Entering a `while` takes one cycle and then, if the block inside is
a single combinational chain, it takes exactly one cycle per iteration.
Exiting a `while` takes one cycle ; however when chaining
loops only one cycle is required to enter the next loop. So the first
loop takes one cycle to enter, any additional loop afterwards adds a single cycle
if there is nothing in between them, the last loop takes one cycle to exit.

Now, `if-then-else` is slightly more subtle. When applied to sequences
of operations not requiring any control flow, an `if-then-else`
synthesizes to a combinational `if-then-else`. This means that both the
’if’ and ’else’ code are evaluated in parallel as combinational chains,
and a multiplexer selects which one is the result based on the
condition. This applies recursively, so combinational `if-then-else` may
be nested.

When the `if-then-else` contains additional control flow (e.g. a
subroutine call, a `while`, a `++:`, a `goto`, etc.) it is automatically
split into several states. It then takes one cycle to exit the ’if’ or
’else’ part and resume operations. If only the ’if’ or the ’else’
requires additional states while the other is a one-cycle block (possibly empty),
an additional state is still required to ’jump’
to what comes after the `if-then-else`. So in general this will cost one
cycle. However, in cases where this next state already exists, for
instance when the `if-then-else` is at the end of a `while` loop, this
existing state is reused resulting in no overhead.

This has interesting implications. Consider the following code:

``` c
while(...) {
  if (condition) {
    ...
++:
    ...
  }
  a = b + 1; // line 7
}
```

When the `if` is not taken, we still have to pay one cycle to reach line
7. That is because it has been placed into a separate state to jump to
it since the `if` is *not* a one-cycle block (due to `++:`). Hence, the
while loop will always take at least two cycles.

However, you may choose to duplicate some code (and hence some
circuitry!) to avoid the extra cycle, rewriting as:

``` c
while(...) {
  if (condition) {
    ...
++:
    ...
    a = b + 1;
  } else {
    a = b + 1;
  }
}
```

This works because when the `if` is taken the execution simply goes back
to the start of the `while`, a state that already exists. The `else`
being a one-cycle block followed by the start of the `while` no extra
cycle is necessary! We just tradeoff a bit of circuit size for extra
performance.

### Switches

Silice also supports the `switch-case` syntax, as follows:

``` c
switch( <EXPR> ) {
  case <CONST>: {  /* code for this case */    }
  case <CONST>: {  /* code for this case */    }
  default:      {  /* code for default case */ }
}
```
where `<EXPR>` is an expression and `<CONST>` are constants.

There is also a onehot version:
``` c
onehot( <IDENTFIER> ) {
  case 0: {  /* code for this case */    }
  case 1: {  /* code for this case */    }
  ...
  case <W-1>: {  /* code for this case */    }
  default:    {  /* code for default case */ }
}
```
where `<IDENTFIER>` is a variable of width `W` and each case is activated for
the corresponding bit of `<IDENTFIER>` being set to `1`, with all other bits set to `0`.
The `default` is only mandatory if not all bits are tested, and otherwise
only necessary if `<IDENTFIER>` may be zero (not having a default while `<IDENTFIER>`
may be zero leads to undefined behaviors).

## Cycle costs of calls to algorithms and subroutines

A synchronized call to an algorithm takes at best two cycles: one cycle
for the algorithm to start processing, and one cycle to register that
the algorithm is done. An asynchronous call does not require additional
cycles (the called algorithm will start running on the next clock
cycle), while a synchronization inserts a state in the control flow and
always requires at least one additional cycle, even if the algorithm is
already finished.

A synchronized call to a subroutine takes at best two cycles: one cycle
to jump to the subroutine initial state, and one cycle to jump back.

> **Note:** Keep in mind that algorithms can also autorun and have their inputs/outputs bound to variables. Algorithms may also contain an `always_before` or `always_after` blocks that are always running.



# Pipelines

> **To be written.** In the meantime please refer to these projects:
 [pipeline_sort](../projects/pipeline_sort/README.md) (has detailed explanations) and [divstd_pipe](../projects/divstd_pipe/README.md).

# Advanced language constructs

## Groups

Often, we want to pass around variables that form conceptual groups,
like the interface to a controller or a 2D point. Silice has a specific mechanism to
help with that. A group is declared as:

``` c
// SDRAM interface
group sdram_32b_io
{
  uint24 addr       = 0,
  uint1  rw         = 0,
  uint32 data_in    = 0,
  uint32 data_out   = 0,
  uint1  busy       = 1,
  uint1  in_valid   = 0,
  uint1  out_valid  = 0
}
```

Note that group declarations are made *outside* of algorithms. Group members
can also use configuration initializers, e.g. `uint24 addr(0), ...`

A group variable can then be declared directly:

``` c
sdram_32b_io sd; // init values are defined in the group declaration
```

To pass a group variable to an algorithm, we need to define an interface
(see also [interfaces](#anonymous-interfaces)).
This will further specify which group members are input and outputs:

``` c
algorithm sdramctrl(
  // ..
  // anonymous interface
  sdram_provider sd {
    input   addr,       // address to read/write
    input   rw,         // 1 = write, 0 = read
    input   data_in,    // data from a read
    output  data_out,   // data for a write
    output  busy,       // controller is busy when high
    input   in_valid,   // pulse high to initiate a read/write
    output  out_valid   // pulses high when data from read is
}
) {
  // ..
```

Binding to the algorithm is then a single line ; in the parent:

``` c
sdramctrl memory(
  sd <:> sd,
  // ..
);
```

The `<::>` operator can also be used in the binding of an interface (see also [bindings](#bindings)).

A group can be passed in a call if the algorithm describes an anonymous interface. If the interface has both inputs and outputs, the group can appear both as an input and an output in the call.

> **Note:** A group cannot contain tables nor other groups.

## Interfaces

### Anonymous interfaces

Interfaces can be declared for a group during algorithm definition.

```c
group point {
  int16 x = 0,
  int16 y = 0
}

algorithm foo(
  point p0 {
    input x,
    input y,
  },
  point p1 {
    input x,
    input y,
  }
) {
  // ..
```

To simplify the above, and when group members are all bound either as inputs or outputs, as simpler syntax exists:
```c
algorithm foo(
  input point p0,
  input point p1
) {
  // ..
```

Anonymous interfaces allow groups to be given as parameters during calls.

### Named interfaces

Named interfaces are ways to describe what inputs and outputs an algorithm expects, without knowing in advance the exact specification of these fields (e.g. their widths).
Besides making algorithm IO description more compact, this provides genericity.

Named interfaces **have** to be bound to a group
(see [named interfaces](#named-interfaces)) or an interface upon algorithm instantiation. They cannot be used to pass a group in a call. The binding does not have to be complete: it is possible to bind to an interface a group having **more** (not less) members than the interface.

Reusing the example [above](#groups) we can define a named interface ahead of time:

``` c
interface sdram_provider {
  input   addr,       // address to read/write
  input   rw,         // 1 = write, 0 = read
  input   data_in,    // data from a read
  output  data_out,   // data for a write
  output  busy,       // controller is busy when high
  input   in_valid,   // pulse high to initiate a read/write
  output  out_valid   // pulses high when data from read is
}
```

And then the sdram controller algorithm declaration simply becomes:

``` c
  algorithm sdramctrl(
    // interface
    sdram_provider sd,
    // ..
  ) {
    // ..
```

Note than the algorithm is now using a named interface, it does not
know in advance the width of the signals in the interface. This is
determined at binding time, when a group is bound to the interface.
Interfaces can be bound to other interfaces, the information is
propagated when a group is bound at the top level.

For instance, we may define another group as follows, which uses 8 bits
instead of 32 bits:

``` c
  // SDRAM interface
  group sdram_8b_io
  {
    uint24 addr       = 0,
    uint1  rw         = 0,
    uint8  data_in    = 0,
    uint8  data_out   = 0,
    uint1  busy       = 1,
    uint1  in_valid   = 0,
    uint1  out_valid  = 0
  }
```

This group can be bound to the `sdramctrl` controller, which now will
receive 8 bits signals for `data_in`/`data_out`.

The `sdramctrl` controller can adjust to this change, using `sameas` and
`widthof`. The first, `sameas`, allows to declare a variable the same as
another:

``` c
sameas(sd.data_in) tmp;
```

The second, `widthof`, returns the width of a signal:

``` c
while (i < (widthof(sd.data_in) >> 3)) {
  // ...
}
```

> **Note:** In the future Silice will provide compile time checks, for instance verifying the width of a signal is a specific value.


## Bitfields

There are many cases where we pack multiple data in a larger variable,
for instance:

``` c
  uint32 data = 32hffff1234;
  // ..
  left  = data[ 0,16];
  right = data[16,16];
```

The hard coded values make this type of code quite hard to read and
difficult to maintain. To cope with that, Silice defines bitfields. A
bitfield is first declared:

``` c
bitfield Node {
  uint16 right,
  uint16 left
}
```

Note that the first entry in the list is mapped to the higher bits of
the field.

This can then be used during access, to unpack the data:

``` c
left  = Node(data).left;
right = Node(data).right;
```

There is no overhead to the mechanism, and different bitfield can be
used on a same variable depending on the context (e.g. instruction
decoding).

The bitfield can also be used to initialize the wider variable:

``` c
uint32 data = Node(left=16hffff,right=16h1234);
```

## Intrinsics

Silice has convenient intrinsics:

-   `__signed(exp)` indicates the expression is signed (Verilog
    `$signed`)

-   `__unsigned(exp)` indicates the expression is unsigned (Verilog
    `$unsigned`)

-   `__display(format_string,value0,value1,...)` maps to Verilog
    `$display` allowing text output during simulation.

-   `__write(format_string,value0,value1,...)` maps to Verilog
    `$write` allowing text output during simulation without a new line being started.

# Lua preprocessor

A preprocessor allows to change the way the source code is seen by the
compiler. It sits between the input source code and the compiler, and
basically rewrites the original source code in a different way, before
it is input to the compiler. This allows compile-time behaviors, such as
adapting the code to a target platform.

Having a strong preprocessor is important for hardware design. For
instance, designing a sort network of some size *N* is best done by
generating the code automatically from a preprocessor, so that one can
easily reuse the same code for different values of *N*. The same is true
of a division algorithm for some bit width, or for the pre-computations
of lookup tables.

The Silice preprocessor is built above the Lua
language <https://lua.org>. Lua is an amazing powerful, lightweight
scripting language that originated in the Computer Graphics community.
The preprocessor is thus not just a macro system, but a fully fledged
programming language.

## Principle and syntax

Preprocessor code is directly interleaved with Silice code. At any
point, the source code can be escaped to the preprocessor by starting a
line with $$. The full line is then considered as preprocessor Lua code.

The pre-processor sees Silice source lines as strings to be output.
Thus, it outputs to the compiler any line that is met during the
execution of the preprocessor. This means it does not output those that
are not reached, and it outputs multiple times those that appear in a
loop.

Let’s make a quick example:

``` c
algorithm main()
{

$$if true then
  uint8 a=0;
  uint8 b=0;
$$end

$$if false then
uint8 c=0;
$$end

$$for i=0,1 do
b = a + 1;
$$end
}
```

The code output by the preprocessor is:

``` c
algorithm main()
{

uint8 a=0;
uint8 b=0;

b = a + 1;
b = a + 1;

}
```

Note that source code lines are either fully Silice, of fully
preprocessor (starting with $$). A second syntax allows to use
preprocessor variables directly in Silice source code, simply doing
$`varname`$ with `varname` the variable from the preprocessor context.
In fact, a full Lua expression can be used in between the $ signs; this
expression is simply concatenated to the surrounding Silice code.

Here is an example:

``` c
algorithm main()
{
$$for i=0,3 do
uint8 a_$i$ = $100+i$;
$$end
}
```

The code output by the preprocessor is:

``` c
algorithm main()
{
uint8 a_0 = 100;
uint8 a_1 = 101;
uint8 a_2 = 102;
uint8 a_3 = 103;
}
```

If a large chunk of Lua code has to be written, you can simply write it
in a separate `.lua` file and use:

``` c
$$dofile('some_lua_code.lua')
```

## Includes

The preprocessor is also in charge of including other Silice source code
files, using the syntax `$include(’source.si’)`. This loads the entire
file (and recursively its own included files) into the preprocessor
execution context.

## Pre-processor image and palette functions

The pre-processor has a number of function to facilitate the inclusion
of images and palette data ; please refer to the example projects
`vga_demo`, `vga_wolfpga` and `vga_doomchip`.

# Interoperability with Verilog modules

Silice can inter-operate with Verilog.

Verilog source code can be included in two different ways:
`append(’code.v’)` and `import(’code.v’)` where `code.v` is a Verilog
source code file.

## Append

Append is very simple: the Verilog source code is directly appended to
the output of the compiler (which is a Verilog source code) without any
processing. This makes this Verilog code available for other Verilog
modules, in particular those that are imported (see next). The reason
for `append` is that Silice is currently not able to fully parse Verilog
when importing.

## Import

Import is the most interesting way to inter-operate with Verilog. Once
imported, all Verilog modules from the Verilog source file will be
available for inclusion in algorithms.

The modules are instantiated in a very similar way as units, with
bindings to variables and dot syntax.

## Wrapping

Due to the fact that Silice only understands a subset of Verilog, there
are cases where a module cannot be imported directly. In such cases,
wrapping offers a solution. The idea is to write a simpler Verilog
module that can be imported by Silice and wraps the instantiation of the
more complex one.

Then the complex module is included with `append` and the wrapper with
`import`.

# Host hardware frameworks

The host hardware framework typically consists in a Verilog glue file.
The framework is appended to the compiled Silice design (in Verilog).
The framework instantiates the *main* algorithm. The resulting file can
then be processed by the vendor or open source FPGA toolchain (often
accompanied by a hardware constraint file).

Silice comes with [many host hardware frameworks](../frameworks/boards/), some examples:

-   **mojov3** : framework to compile for the Alchitry Mojo 3 FPGA
    board.

-   **icestick** : framework for the icestick board.

-   **icebreaker** : framework for the icebreaker board.

-   **ulx3s** : framework for the ULX3S board.

-   **de10nano** : framework for the de10-nano board.

-   **verilator** : framework for use with the *verilator*
    hardware simulator

-   **icarus** : framework for use with the *icarus* hardware
    simulator

For practical usage examples please refer to the [*Getting started* guide](../GetStarted.md).

New frameworks for additional boards [can be easily created](../frameworks/boards/README.md).

## VGA and OLED simulation

The Silice verilator framework supports VGA and OLED display out of the box. For instance see the [VGA demos project](../projects/vga_demo/README.md).

[1] http://iverilog.icarus.com/

[2] https://www.veripool.org/wiki/verilator

[3] See the famous Dijkstra’s paper about this.
