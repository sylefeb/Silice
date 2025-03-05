# Silice
## *A language for hardcoding Algorithms into FPGA hardware*

This is the Silice main documentation.

When designing with Silice your code describes circuits. If not done already, I recommended to [watch the introductory video](https://www.youtube.com/watch?v=_OhxEY72qxI) (youtube) to get more familiar with this notion and what it entails. The video is slightly outdated in terms of what Silice can do, but still useful when getting started.

## Table of content

- [Silice](#silice)
  - [*A language for hardcoding Algorithms into FPGA hardware*](#a-language-for-hardcoding-algorithms-into-fpga-hardware)
  - [Table of content](#table-of-content)
- [Tutorial](#tutorial)
- [A first example](#a-first-example)
- [Terminology](#terminology)
- [Basic language constructs](#basic-language-constructs)
  - [Types](#types)
  - [Constants](#constants)
  - [Variables](#variables)
  - [Tables](#tables)
  - [Block RAMs / ROMs](#block-rams--roms)
      - [Block ROMs](#block-roms)
      - [Dual-port RAMs](#dual-port-rams)
  - [Operators](#operators)
    - [Swizzling](#swizzling)
    - [Arithmetic, comparison, bit-wise, reduction, shift](#arithmetic-comparison-bit-wise-reduction-shift)
    - [Concatenation](#concatenation)
    - [Bindings](#bindings)
    - [Expression trackers](#expression-trackers)
  - [Control flow](#control-flow)
    - [The step operator](#the-step-operator)
    - [The pipeline operator](#the-pipeline-operator)
- [Units and algorithms](#units-and-algorithms)
    - [main (design 'entry point').](#main-design-entry-point)
  - [Unit declaration](#unit-declaration)
      - [*Inputs and outputs.*](#inputs-and-outputs)
      - [*Declarations.*](#declarations)
      - [*Always assign.*](#always-assign)
  - [Instantiation](#instantiation)
      - [Automatic binding.](#automatic-binding)
      - [Direct access to inputs and outputs.](#direct-access-to-inputs-and-outputs)
  - [Call](#call)
  - [Subroutines](#subroutines)
  - [Circuitry](#circuitry)
    - [Instantiation time specialization](#instantiation-time-specialization)
  - [Combinational loops](#combinational-loops)
  - [Always assignments](#always-assignments)
  - [Always blocks](#always-blocks)
  - [Clock and reset](#clock-and-reset)
  - [Modifiers](#modifiers)
- [Execution flow and cycle utilization rules](#execution-flow-and-cycle-utilization-rules)
  - [Cycle report](#cycle-report)
  - [Control flow](#control-flow-1)
    - [Switches](#switches)
  - [Cycle costs of calls to algorithms and subroutines](#cycle-costs-of-calls-to-algorithms-and-subroutines)
- [Pipelines](#pipelines)
  - [Special assignment operators](#special-assignment-operators)
  - [The `stall` keyword](#the-stall-keyword)
  - [Pipelines in algorithm](#pipelines-in-algorithm)
    - [Parallel pipelines](#parallel-pipelines)
    - [Multiple steps in a stage](#multiple-steps-in-a-stage)
    - [Pipelines and circuitries](#pipelines-and-circuitries)
  - [Pipelines in always blocks](#pipelines-in-always-blocks)
- [Other language constructs](#other-language-constructs)
  - [Groups](#groups)
  - [Interfaces](#interfaces)
    - [Anonymous interfaces](#anonymous-interfaces)
    - [Named interfaces](#named-interfaces)
  - [Bitfields](#bitfields)
  - [Intrinsics](#intrinsics)
- [Lua preprocessor](#lua-preprocessor)
  - [Principle and syntax](#principle-and-syntax)
  - [Includes](#includes)
  - [Instantiation time preprocessor](#instantiation-time-preprocessor)
  - [Preprocessor constraints](#preprocessor-constraints)
  - [Preprocessor image and palette functions](#preprocessor-image-and-palette-functions)
- [Interoperability with Verilog modules](#interoperability-with-verilog-modules)
  - [Append](#append)
  - [Import](#import)
  - [Wrapping](#wrapping)
- [Host hardware frameworks](#host-hardware-frameworks)
  - [VGA and OLED simulation](#vga-and-oled-simulation)

GitHub repository: <https://github.com/sylefeb/Silice/>

# Tutorial

If you prefer to learn by looking at some code and trying out things, please
check out the [Silice tutorial](README.md).

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
-   **one-cycle block**: A block of operations that require a single
    cycle (no loops, breaks, etc.).
-   **combinational chain**: A sequence of operations that result in a circuit
    updating variable states within a single cycle, typically a one-cycle block
    or instructions between [step operators](#control-flow-the-step-operator).
-   **combinational loop**: A circuit where a cyclic
    dependency exists. These lead to unstable hardware synthesis and
    have to be avoided.
-   **VIO**: A Variable, Input or Output.
-   Host hardware **framework**: The Verilog glue to the hardware meant
    to run the design. This can also be a glue to [Icarus](http://iverilog.icarus.com/)
    or [Verilator](https://www.veripool.org/wiki/verilator), both frameworks are provided.

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

Outside of algorithms and always blocks, variables can be *bound* to expressions,
thus tracking the value of the expression.
This is done during the variable declaration, using either
the `<:` or `<::` binding operators.

Example:

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

In this case `o` gets assigned 15+3 on line 11, as it tracks
the expression `a+b`. Note that the variable `a_plus_b`
becomes read only (in Verilog terms, this is now a wire). We call `o` an
expression tracker or bound expression.

The second operator, `<::` tracks the expression with a one cycle latency. Thus, its value is the value of the expression at the previous cycle. If used
in this example, `o` would evaluate to `1+2`.

> The `<::` operator is *very useful*. It allows to relax timing constraints (reach higher frequencies), by accepting a one cycle latency. As a general rule, using delayed operators (indicated by `::`) is recommended whenever possible.

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

## Control flow

### The step operator

Placing a `++:` in the sequence of operations of an algorithm explicitly
asks Silice to wait for exactly one cycle at this precise location in
the execution flow. Each next `++:` waits one additional cycle.

This has several important applications such as waiting for a memory
read/write, or breaking down long combinational chains that would
violate timing.

### The pipeline operator

Placing a `->` in the sequence of operations of an algorithm explicitly
asks Silice to pipeline the one-cycle sequence before with the next.
Each next `->` adds a pipeline stage.

Control flow operators (`++:` and `->`) can be combined, with `->` having a higher
priority. Please refer to the [Section on pipelines](#pipelines) for more details.

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
declared (in any order). A simple example:

``` c
algorithm main(output uint8 led)
{
  uint8 r = 0;
  adder ad1;

  // ... btw this is a comment
}
```

Variables can also be declared as assigned expressions anywhere within an
algorithm or always block.

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
equivalent of local routines, without having to wire all the parent
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

> Circuitries have become a powerful tool in Silice.
> They define pieces of algorithms and pipelines that can be later
> assembled together, with mechanisms for genericity.
> Intuitively they are similar to inline, templated functions.

Sometimes, it is useful to write a generic piece of code that can be
instantiated repeatedly within a design. Such an example is a piece of
circuitry to write into an SDRAM, which bit width may not ne known in advance.

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

```verilog
circuitry writeData(inout sd,input addr,input data) {
  // wait for sdram to not be busy
  while (sd.busy) { /*waiting*/ }
  // write!
  sd.data_in      = rdata;
  sd.addr         = addr;
  sd.in_valid     = 1;
}
```

Note the use of `inout` for sd (which is a group, see
Section <a href="#groups">groups</a>).
A circuitry is not called, it is instantiated. This means that every
instantiation is indeed a duplication of the circuitry.

Here is the syntax for instantiation:

```verilog
(output_0,...,output_N) = ID(input_0,...input_N)
```

As for algorithms and subroutines, inputs and outputs have to appear in
the order of declaration in the lists. An inout appears twice, both as
output and input. Following the previous example here is the
instantiation from an algorithm:

```verilog
(sd) = writeData(sd,myaddr,abyte);
```

### Instantiation time specialization

The exact shape of the circuitry is determined when it is instanced. Therefore
it is possible, through the pre-processor, to adjust the circuitry to its exact
context. Here is a [first example](../tests/circuits15.si) where the width of
the result is used to generate a different code each time:

```c
circuitry msbs_to_one(output result)
{
  $$for i=widthof('result')>>1,widthof('result')-1 do
    result[$i$,1] = 1;
  $$end
}

algorithm main(output uint8 leds)
{
  uint12 a(0); uint20 b(0);
  (a) = msbs_to_one();
  (b) = msbs_to_one();
  __display("a = %b, b = %b",a,b);
}
```

Result is: ```a = 111111000000, b = 11111111110000000000```. Internally
two different pieces of code have been generated when assembly the circuitry.

A circuit being instantiated can receive other parameters, [for instance](circuits16.si):

```c
circuitry add_some(input a,output b)
{
  b = $N$ + a;
	//  ^^^ this is how we get the value of instantiation-time parameter N
	//  (pre-processor syntax)
}

unit main(output uint8 leds)
{
  uint8  m(123);
  uint8  n(0);
  algorithm {
    (n) = add_some<N=50>(m);
    __display("result = %d",n);
    (n) = add_some<N=100>(m);
    __display("result = %d",n);
  }
}
```

Result is:
```
result = 173
result = 223
```

So indeed the first circuitry `add_some<N=50>` adds 50, the second
`add_some<N=100>` adds 100.

To conclude let's see a more advanced example of a [recursive circuitry
definition](circuits17.si).

```c
circuitry rec(output v)
{
  $$if N > 1 then
    sameas(v) t1(0); // t1 will be same type as v
    sameas(v) t2(0); // t2 will be same type as v
    (t1) = rec< N = $N>>1$ >(); // recursive instantiation with N/2
    (t2) = rec< N = $N>>1$ >(); // recursive instantiation with N/2
    v = t1 + t2;     // evaluates to sum of both half results
  $$else
    v = 1; // bottom of recursion: evaluates to 1
  $$end
}

algorithm main(output uint8 leds)
{
  uint10  n(0);
  (n) = rec<N=16>(); // instantiate for size 16
  __display("result = %d",n);
}
```

This toy example produces a tree of instantiations, instantiating two circuits
using half the parameter value (N/2) until N is equal to 1. The leaves
evaluate to 1, and for a top instantiation of size $N=2^p$ we expect the result
to evaluate to $2^p$ (since there are $2^p$ leaves in a binary tree of
depth $p$). We indeed get: ```result = 16```.

## Combinational loops

When writing code, you may encounter a case where the Silice compiler
raises an error due to an expression leading to a combinational loop.
This indicates that the sequence of operations is leading to a cyclic
dependency in the circuit being described. These are in most cases
undesirable as they lead to unpredictable hardware behaviors.

A trivial solution is such a situation is to split the circuit loop
using the *step* operator (see
Section [step operator](#control-flow-the-step-operator)).
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
tracks two versions: the value at the cycle start and the value being modified (corresponding to a hardware flip-flip DQ pair). So `a = a + 1` in fact means
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

Upon compilation, Silice breaks down the code into finite state
machines (FSM) . Each FSM state corresponds to a circuit that
updates the variables within a single cycle, and selects the next state.
We next call these circuits *combinational chains*.

Silice attempts to form the longest combinational chains, or equivalently
to minimize the number of states in the FSM. That is because going from one
state to the next requires one clock cycle, delaying further computations.
Of course, longer combinational chains also lead to reduced clock frequency,
so there is a tradeoff. This is why Silice lets you explicitly specify
where to cut a combinational chain using the step operator `++:` or create
pipelines with the pipelining operator `->`.

Note that if a state contains several independent combinational chain,
they will execute as parallel circuits (e.g. two computations regarding
different sets of variables). Grouping such computations in a same state
increases parallelism, without deepening the combinational chains.

The use of control flow structures such as `while` (or `goto`), as well
as synchronization with other algorithms also require introducing states.
This results in additional cycles being introduced. Silice follows a set
of precise rules to do this, so you always know what to expect.

> Rarely, additional optimizations may be introduced that change the behavior
of your code. To mitigate the impact of such changes, Silice outputs a detailed
change log report after compilation.
All changes are also [documented here](../ChangeLog.md).

## Cycle report

Silice now has the ability to show how a design is split into cycles. The
report outputs in the console the source code, with each line colored based
on the state it belongs to.

Let's try it on a simple example. Enter `projects/vga_demo` and run
`make verilator`. Close the simulation window. From the command line enter
`report-cycles.py verilator vga_rototexture.si`. The output is the source
code color coded by how each line maps to a cycle.


## Control flow

The most basic control flow operation is `goto`. While it may be used
directly, it is recommended to prefer higher level primitives such as
`while` and subroutines, because `goto` often leads to harder to read
and maintain code[3]. Yet, they are a fundamental low-level operation
and Silice is happy to expose them for your enjoyment!

Goto labels are added with the `<LABEL_NAME>:` syntax at the
beginning of a line, for instance:
```c
  a = b + 1;
  if (a == 0) {
    goto error;
  }
  goto done;
error:
  leds = 255;
done:
```

`goto` always requires one cycle to ’jump’: this is a change of state in
the FSM. It also introduces a label at the jump destination, since control flow
has to start at this location.

> **Note:** If a user label is never jumped to from a goto, no additional cycle
is introduced and the label has no effect. However, `++:` always introduces
a cycle.

Entering a `while` takes one cycle and then, if the block inside is
a single combinational chain, it takes exactly one cycle per iteration.
Exiting a `while` does *not* take a cycle, the combinational chain located after
is reached as soon as the `while` condition becomes false.

When chaining loops only one cycle is required to enter the next loop. So the
first loop takes one cycle to enter, any additional loop afterwards adds a
single cycle.

Let us now consider `if-then-else`. Under most circumstances, no other cycles
are introduced than those required within the branches themselves (`if`/`else`),
for instance when a branch contains a subroutine call, a `while`, a `++:`,
a `break`. If the branches do not require any cycles, then the `if-then-else`
does not require any additional cycle itself (and this is recursively true for
nested `if-then-else` of course).

When one or both branches of the `if-then-else` require additional cycles, and
both control flow branches (`if` and `else`) reach after the `if-then-else`,
a cycle *will* be introduced. If only one branch reaches after, no additional
cycle is required.

Let us take some example to understand the implication of that. The loops
below iterate in one cycle unless the `if` is taken:
```c
while (...) {
  if (condition) {
    ...
    ++:
    ...
    goto exit:
  } else {
    a = a + 1;
  }
  // no extra cycle here
  b = b + 1;
}
exit:
```
Here, the `if` branch requires multiple cycles, but never reaches after the
`if-then-else` since it jumps directly to `exit`.

```c
while (...) {
  if (condition) {
    ...
    break;
  }
  // no extra cycle here
  a = a + 1;
}
```
Likewise, the `if` breaks out of the loop and does not reach after the
`if-then-else`. No extra cycle is introduced.

Let's now see one case where an extra cycle is introduced:
```c
while (...) {
  if (condition) {
    ...
++:
    ...
  } else {
    ...
  }
  // extra cycle here
  b = b + 1; // bookmark [1]
}
```
Here both the `if` and `else` reach after the `if-then-else` (`bookmark [1]`),
while the `if` requires multiple cycles. In such a case a cycle is introduced
just after the `if-then-else`.
That is because control has to return from the `if` to `bookmark [1]`, and thus
introduces a state before this location.

However, you may choose to duplicate some code (and hence some
circuitry) to avoid the extra cycle, rewriting as:

``` c
while(...) {
  if (condition) {
    ...
++:
    ...
    b = b + 1;
  } else {
    ...
    b = b + 1;
  }
}
```

This works because when the `if` is taken the execution simply goes back
to the start of the `while`, a state that already exists. This trades-off a
bit of circuit size for extra performance.

> **Couldn't Silice duplicate the code automatically to remove this cycle?**
Yes it could, however such an automation would potentially result in large
chunks of codes being duplicated, possibly multiple times. As the cost-benefit
is hard to automatically assess, the rule in Silice is to not duplicate code
as an implicit optimization.

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

> Several projects in the repo use pipelines and can provide a good practical introduction:
> [pipeline_sort](../projects/pipeline_sort/README.md) has detailed explanations,
> [divstd_pipe](../projects/divstd_pipe/README.md) uses the pre-processor to produce a pipeline for division when instantiated,
> [Menger sponge](../projects/vga_demo/vga_msponge.si) is a long pipeline rendering a 3D fractal racing the beam in full HD,
> and the [ice-v conveyor and swirl CPUs](../projects/ice-v/README.md) are pipelined CPUs.

The pipeline syntax is:
```c
{
  // stage 0
  // ...
->
  // stage 1
  // ...
->
  // final stage
  // ...
}
```

In essence, a pipeline is composed of one-cycle blocks that all run
simultaneously, in parallel.

If stages are independent and do not communicate through variables, their order
would not matter. But of course the interesting part is how different stages
*can* communicate ; and when they do their order indicates how data flows
through the pipeline.

Typically, each stage works on some data and passes its output to the next stage
at the next cycle. Here is an example of a data stream A,B,C,D traversing a
three stages pipeline just passing the data around:

| cycle   |   i   |  i+1  |  i+2  |   i+3  |   i+4  |   i+5  |   i+6  |
|---------|-------|-------|------ |--------|--------|--------|--------|
| stage 0 |   A   |   B   |   C   |   D    |    .   |    .   |   .    |
| stage 1 |   .   |   A   |   B   |   C    |    D   |    .   |   .    |
| stage 2 |   .   |   .   |   A   |   B    |    C   |    D   |   .    |

A dot (`.`) indicates that the stage is idle (it does not process useful data).

There are a number of interesting observations to be made. The first data token
(`A`) enters the pipeline at cycle `i` and exits it after cycle `i+2`. So there
is a delay of three cycles -- corresponding to the three stages -- between `A`
entering the pipeline and the corresponding result becoming available. This is
called the *latency* of the pipeline.
A second observation is that once `A` exits, then the results for `B`, `C` and
`D` follow each at the next cycles. This is the main advantage of a pipeline:
we pay in latency but then get new results at every next cycle (of course some
pipelines may produce results at a different pace, but one each cycle is typical).
Finally, consider the usage in terms of circuitry. When the pipeline is filled
(see `i+2` and `i+3` above), all stages are active, so the circuitry of all
stages is being fully utilized. This is much more efficient than having only one
stage producing a useful result during a cycle.

How do we tell Silice to pass data around in a pipeline? Well, in fact there is
nothing special to do, simply assign a variable and it will be passed to the subsequent
stages. Let's see a <a id="simple-pipeline"></a>simple example:
```verilog
unit main(output uint8 leds)
{
  uint16 cycle=0; // cycle counter
  algorithm {
    uint16 a=0; uint16 b=0;
    while (a < 3) { // six times
        // stage 0
        a = a + 1; // write to a, it will now trickle down the pipeline
        __display("[stage 0] cycle %d, a = %d",cycle,a);
      -> // stage 1
        __display("[stage 1] cycle %d, a = %d",cycle,a);
      -> // stage 2
        __display("[stage 2] cycle %d, a = %d",cycle,a);
    }
  }
  always_after { cycle = cycle + 1; } // increment cycle
}
```

The result is (grouped by cycle):
```
[stage 0] cycle     2, a =     1

[stage 0] cycle     3, a =     2
[stage 1] cycle     3, a =     1

[stage 0] cycle     4, a =     3
[stage 1] cycle     4, a =     2
[stage 2] cycle     4, a =     1

[stage 1] cycle     5, a =     3
[stage 2] cycle     5, a =     2

[stage 2] cycle     6, a =     3
```
First, note the pipeline pattern where at cycle 2 only stage 0 is active,
then stages 0 and 1 at cycle 3, and then all three stages at cycle 4. At this
point all three value of `a` are in the pipeline (one in each of the stages).
Since no new values are produced at stage 0, the pipeline starts to empty at
cycle 5, and terminates at cycle 6.

> Why do we not start at cycle 0? This is due to the way the simulation
> framework is written, with a reset sequence taking two cycles.

At cycle 4, note how each stage sees a different value of `a`. (e.g. `stage 0`
sees `a=3`, `stage 1` sees `a=2`, `stage 2` sees `a=1`). Note also that the
oldest value of `a` (the first produced) is in the latest stage (`stage 2`).
As you can see, Silice took care of passing `a` through the pipeline.
In Silice terminology, `a` has been *captured* at stage 0 and *trickles down*
the pipeline between stages.

**Wait, how does the pipeline interact with the while loop?**
Excellent question! Think of it this way: the pipeline is always there waiting
for data to enter. The while loop is actually *feeding* stage 0 of the pipeline.
When the while loop terminates the pipeline keeps going until done. The
algorithm does not terminate until all of its pipelines are done. We discuss
this in [more details later](#pipelines-in-algorithm).

## Special assignment operators

By default, any variable assigned at a given stage immediately starts trickling
down. In many cases nothing else is needed. But of course there are ways to
control that behavior. In a pipeline, there are three
special assignement operators:
- The *backward assign* operator `^=`
- The *forward assign* operator `v=`
- The *after pipeline* assign operator `vv=`

Let's consider [this example](../tests/pipeline_ops.si):
```c
    // pipeline
    {
        a = a + 1;
        __display("[%d, stage 0] a=%d b  =%d c   =%d  d   =%d",cycle,a,b,c,d);
     ->
        a = a + 100;
        b ^= a;  // all stages see the new value of b within the same cycle.
        c v= a;  // stage 2 (and all after stage 1) see the new value of c within
                 // the same cycle (stage 0 does not, it will see the new value
                 //  of c only at the next cycle).
        d vv= a; // other stages will see the update at next cycle
        __display("[%d, stage 1] a=%d b ^=%d  c v=%d  d vv=%d",cycle,a,b,c,d);
     ->
        __display("[%d, stage 2] a=%d b  =%d c   =%d  d   =%d",cycle,a,b,c,d);
    }
```

The output (formatted for clarity) is:
```
[  0, stage 0] a=    1 b  =  100 c  =    0 d   =    0
[  0, stage 1] a=  100 b ^=  100 c v=  100 d vv=  100
[  0, stage 2] a=    0 b  =  100 c  =  100 d   =    0

[  1, stage 0] a=    2 b  =  101 c  =  100 d   =  100
[  1, stage 1] a=  101 b ^=  101 c v=  101 d vv=  101
[  1, stage 2] a=  100 b  =  101 c  =  101 d   =  100

[  2, stage 0] a=    3 b  =  102 c  =  101 d   =  101
[  2, stage 1] a=  102 b ^=  102 c v=  102 d vv=  102
[  2, stage 2] a=  101 b  =  102 c  =  102 d   =  101

[  3, stage 0] a=    4 b  =  103 c  =  102 d   =  102
[  3, stage 1] a=  103 b ^=  103 c v=  103 d vv=  103
[  3, stage 2] a=  102 b  =  103 c  =  103 d   =  102

[  4, stage 0] a=    5 b  =  104 c  =  103 d   =  103
[  4, stage 1] a=  104 b ^=  104 c v=  104 d vv=  104
[  4, stage 2] a=  103 b  =  104 c  =  104 d   =  103
```

Let's first consider `b`. It is assigned in stage 1 with `^=`. This means the
change will be immediately visible to all stages. And indeed, `b` has the same
value every cycle in all stages (`100`, `101`, ..., `104`).

Let's now consider `c`. It is assigned in stage 1 with `v=`. This means stages
located *on and after* stage 1 (here, stages 1 and 2) will see this change immediately. And indeed, in the
output we can see that `c` has the same value in stages 1 and 2, but a different
value (the previous one) in stage 0.

Let's now consider `d`. It is assigned in stage 1 with `vv=`. Stages 0 and 2
will see this change only *at the next cycle*. And indeed, each cycle the value
of `d` in stages 0 and 2 is one cycle behind that of stage 1.

`a` itself behaves normally, trickling down the pipeline every cycle.

Taken together, these operators afford for a lot of flexibility in pipelines.
One typical use is to deal with data hazards (see the [ice-v conveyor and swirl CPUs](../projects/ice-v/README.md)).
Note however that the assignments could contradict each other and lead to
impossible cyclic constraints. Silice will issue an error in such cases.

## The `stall` keyword

In some cases a pipeline stage cannot immediately deal with the received value:
it has to pause for a cycle before reconsidering. A pipeline stage can indicate
that it needs to pause the pipeline by calling `stall;`. This will pause all
stages located before. Stages located after will continue processing their valid
input, but a *bubble* is introduced in the pipeline at the next stage: the
bubble is a non valid input, meaning subsequent stages will do nothing as they
receive this invalid input.

For instance, in the example below stage 1 decided to stall at cycle `i+2`. See
how stage 2 was subsequently empty at `i+3` (this is the *bubble*) while the
input of stages 0 and 1 did not change between cycles `i+2` and `i+3`. After
that the pipeline resumes as normal.

| cycle   |   i   |  i+1  |  i+2          |   i+3  |   i+4  |   i+5  |   i+6  |
|---------|-------|-------|------         |--------|--------|--------|--------|
| stage 0 |   A   |   B   |   C           |   C    |    D   |    .   |   .    |
| stage 1 |   .   |   A   |   B **stall** |   B    |    C   |    D   |   .    |
| stage 2 |   .   |   .   |   A           |   .    |    B   |    C   |   D    |

> `stall` is a powerful and convenient operator. However, beware that it will
> negatively impact maximum frequency on pipelines with many stages, since
> it introduces a feedback from later stages to earlier stages.

## Pipelines in algorithm

A powerful feature of Silice is to enable pipelines to be started from within
algorithms, and pipelines stages can also have multiple steps using the `++:`
operator.

### Parallel pipelines

We have seen a [first example](#simple-pipeline) where the pipeline is fed from
the while loop. It is possible to define and feed pipelines from anywhere,
[for instance](../tests/pipeline_alg2.si):

```c
unit main(output uint8 leds)
{
  uint16 cycle = 0; // cycle counter
  algorithm {
    uint8 a = 0;
    // a first pipeline adding +4 every stage
    { uint8 b=a+4; -> b=b+4; -> b=b+4; -> b=b+4; -> __display("cycle %d [end of pip0] b = %d",cycle,b); }
    // a second pipeline adding +1 every stage
    { uint8 b=a+1; -> b=b+1; -> b=b+1; -> b=b+1; -> __display("cycle %d [end of pip1] b = %d",cycle,b); }
++:
    __display("cycle %d [bottom of algorithm]",cycle);
  }
  always_after { cycle = cycle + 1; } // increment cycle
}
```
The result is:
```
cycle     2 [bottom of algorithm]
cycle     5 [end of pip0] b =  16
cycle     5 [end of pip1] b =   4
```
Note how both pipelines end exactly at the same cycle (cycle 5). That is because
they were fed together at the same step of the algorithm. They effectively
operate in parallel!

Note also how we reach the 'bottom' of the algorithm *before* the pipelines end.
This is an important rule: an algorithm does not return until all of its
pipelines are done, which is why the pipelines properly terminate even though
the algorithm bottom was reached.

> **Note:** Pipelines cannot be nested (for now at least...).

### Multiple steps in a stage

Let's see how each stage can have a different number of steps.
Consider [this example](../tests/pipeline_alg3.si):

```c
unit main(output uint8 leds)
{
  uint16 cycle = 0; // cycle counter
  algorithm {
    uint16 a = 0;
    while (a<3) { // this pipeline has a middle stage that takes multiple cycles
      // stage 0
      uint16 b = a;
      __display("cycle %d [stage 0] b = %d",cycle,b);
      a = a + 1;
  ->
      // stage 1
      b = b + 10;
    ++: // step
      b = b + 100;
    ++: // step
      b = b + 1000;
  ->
     // stage 2
      __display("cycle %d [stage 2] b = %d",cycle,b);
    }
  }
  always_after { cycle = cycle + 1; } // increment cycle
}
```

The result is:

```
cycle     2 [stage 0] b =     0
cycle     3 [stage 0] b =     1
cycle     6 [stage 0] b =     2
cycle     6 [stage 2] b =  1110
cycle     9 [stage 2] b =  1111
cycle    12 [stage 2] b =  1112
```

First let's check that we get the expected result. Stage 1 adds 1110 in total
to the value coming from stage 0, while stage 2 simply displays the value
it receives. We can see that stage 0 receives `0`,`1`,`2` and stage 2
reports `1110`,`1111`,`1112`. Correct!

Now let's look at the cycles. The pipeline is first fed on cycle 2 (value `0`
enters stage 0) and then on cycle 3 (value `1`). However, nothing happens until cycle *6* where `2` enters. The reason is simple: stage 1 is taking three steps, so the pipeline
earlier stages (here only stage 0) are stalled. Meanwhile stage 2 is still
waiting for data. Thus, at cycle 4 stage 1 is
doing `b = b + 100` and at cycle 5 `b = b + 1000`. At cycle 6 stage 1 can take
the next value (`1`), while stage 0 now can consider `2` and stage 2 displays
the result `1110`.

Another interesting thing to note is that stage 2 is active every three cycles
(cycles 6,9,12). So this pipeline takes three cycles to produce an output.

Pipeline stages can also use data-dependent while loops. They can even call algorithms!
Of course, favor simple, stateless pipelines whenever possible, but this can
come in handy.

> **Note:** Pipeline stages cannot call subroutines.

### Pipelines and circuitries

A powerful construct is to define pipelines in [circuitries](#circuitry), which
can then be *concatenated* to a current pipeline.

Here is [an example](../tests/circuits18.si):

```c
circuitry add_two(input i,output o)
{ // stage 1
  uint8 v = i + 1;
->
  // stage 2
  o = v + 1;
->
}

unit main(output uint8 leds)
{
  uint32 cycle=0;
  uint8  a    =0;
  algorithm {
    while (a<3) {
      // stage 0
      uint8 v = a;
      __display("cycle %d, first stage, v=%d",cycle,v);
      a = a + 1;
  ->
  (v) = add_two(v); // adds two stages
      // stage 3
      v = v + 100;
  ->
      // stage 4
      __display("cycle %d, last stage, v=%d",cycle,v);
    }
  }
  always_after { cycle = cycle + 1; }
}
```
The output is:
```
cycle 2, first stage, v=  0
cycle 3, first stage, v=  1
cycle 4, first stage, v=  2
cycle 6, last stage,  v=102
cycle 7, last stage,  v=103
cycle 8, last stage,  v=104
```
Everything happens as if the content of the `add_two` circuitry had been cut and
pasted where it is instantiated, with two stage being added to the pipeline.
This is very convenient to defined pieces of pipelines to be added, for instance
a pipelined multiplier.

More advanced examples are in the raymarching pipeline
available in the [demo projects](../projects/vga_demo/vga_msponge.si).

> **Note:** As a good practice suggestion, see how I indented the circuitry
instantiation to align with the pipelining arrows, indicating it does change the
pipeline.

> **Note:** A limitation of the current implementation is that a circuitry
containing a pipeline can only be instantiated within a parent pipeline using
at least one `->`. This will be fixed in the future.

## Pipelines in always blocks

Pipelines in always blocks behave slightly differently. In an always block, all
pipeline stages are active at all times: there are no automatic triggers
enabling/disabling stages as the stages are *always* active,
and the `stall` keyword cannot be used. Special assignment operators are available.

# Other language constructs

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

[Here is an example](../tests/bitfield1.si) that you can run to test bitfields:
``` c
bitfield HL {
  uint4 high,
  uint4 low
}

unit main(output int8 leds)
{
  always {
    uint8 test0 = HL(high=4b1001,low=4b0110);
    __display("test0: %b (high is on MSBs)",test0);
    uint8 test1 = HL(low=4b0110,high=4b1001);
    __display("test1: %b (same as expected)",test1);
    __finish();
  }
}
```

The output of `make bitfield1` (from within the `Silice/tests` directory) is:

```
test0: 10010110 (high is on MSBs)
test1: 10010110 (same as expected)
- build.v:275: Verilog $finish
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
line with `$$`. The full line is then considered as preprocessor Lua code.

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

Note that source code lines are either fully Silice, of fully preprocessor
(starting with `$$`). A second syntax allows to use preprocessor variables
directly in Silice source code, simply doing `$varname$` with *varname* the
variable from the preprocessor context. In fact, a full Lua expression can be
used in between the `$` signs; this expression is evaluated and concatenated as
a string to the surrounding Silice code.

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
files, using the syntax `$include('source.si')`. This loads the entire
file (and recursively its own included files) into the preprocessor
execution context.

## Instantiation time preprocessor

The preprocessor is invoked every time a unit is instantiated. This allows to
specialize the unit within its instantiation context. For instance:

```c
unit mirror(input auto i,output sameas(i) o)
{
  always {
$$for n=0,widthof('i')-1 do
    o[$n$,1] = i[$widthof('i')-1-n$,1];
$$end
  }
}

unit main(output uint8 leds)
{
  uint6  a(6b111000);
  uint11 b(11b11101000011);
  mirror m1(i <: a); // generates a unit for width 6
  mirror m2(i <: b); // generates a unit for width 11
  algorithm {
    __display("m1: %b",m1.o);
    __display("m2: %b",m2.o);
  }
}
```

Here we can see the use of `auto` and `sameas` in the declaration of unit
`mirror`. This allows genericity, determining the types upon instantiation,
from the instance bindings. The preprocessor can also access the width of the
instantiated inputs and outputs by using `widthof`, giving the name of the
input or output as a string. This is for instance used in this preprocessor loop:
```$$for n=0,widthof('i')-1 do ...```

## Preprocessor constraints

There are a few constraints on the preprocessor. Unit declarations should not
be split by preprocessor if-then-else directives. For instance:
```c
$$if BUTTONS then
  unit main(output uint8 leds, input uint3 buttons) {
$$else
  unit main(output uint8 leds) {
$$end
  // ...
}
```
will result in the following error:
```diff
functionalizing unit main
- error: [parser] Pre-processor directives are unbalanced within the unit, this is not supported (please refer to the documentation, Documentation.md#preprocessor-constraints).
```

Instead do:
```c
unit main(
  $$if BUTTONS then
    output uint8 leds, input uint3 buttons
  $$else
    output uint8 leds
  $$end
) {
  // ...
}
```

Preprocessor if-then-else can freely be used between the `(` and `)` of the unit
declaration, and between the `{` and `}` of the unit block.
However there should not be any top level if-then-else enclosing and repeating
these parentheses and braces.

## Preprocessor image and palette functions

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

[3] See the famous Dijkstra’s paper about this.
