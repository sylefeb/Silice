
- [\[CL0001\] Instantiation time pre-processor](#cl0001-instantiation-time-pre-processor)
- [\[CL0002\] Tracker declarations](#cl0002-tracker-declarations)
- [\[CL0003\] Pipeline syntax](#cl0003-pipeline-syntax)
- [\[CL0004\] While loops cycle rules](#cl0004-while-loops-cycle-rules)

## [CL0001] Instantiation time pre-processor

> **Symptom**
```error: [parser] Pre-processor directives are unbalanced within the unit, this is not supported.```

The new instantiation time feature introduced a few constraints on the
pre-processor. A problem that can appear is receiving the error shown above.

Here is a typical case where this might happen:
```lua
$$if ICESTICK then
   algorithm main(output uint5 leds, inout uint8 pmod)
$$else
   algorithm main(output uint5 leds)
$$end
{
  while (1) {  }
}
```

This was typically done to change the main design signature depending on the
target board. This however is no longer supported and requires a change as
shown below:

```lua
algorithm main(
$$if ICESTICK then
  output uint5 leds, inout uint8 pmod
$$else
  output uint5 leds
$$end
) {
  while (1) {
  }
}
```

The rule is that a preprocessor if-then-else can appear between
the `(` and `)` of the algorithm (or unit) in/out declaration, and between
the `{` and `}` of the algorithm block, but there should be no
if-then-else enclosing or repeating these parentheses and braces.

(see also [issue #232](https://github.com/sylefeb/Silice/issues/232))

## [CL0002] Tracker declarations

> **Symptom:** ```^^^^^^^^^^^^^^^^^ expression trackers may only be declared in the unit body, or in the algorithm and subroutine preambles```

[Expression trackers](learn-silice/Documentation.md#expression-trackers)
are a convenient way to track an expression throughout the design. They use
binding operators (`<:` and `<::`) and the binding operator being used defines
whether the tracker tracks the value of the expression as it is changed within
the cycle (`<:`) or with a one-cycle latency (`<::`).

The trackers are now restricted to where they are required to remove ambiguities:
- unit bodies,
- algorithm preambles,
- subroutine preambles.

In all other places, use the new initializing expressions:
```c
uint8 a = b + 5 - c;
```
This will declare variable `a` and initialize it to the given expression.

## [CL0003] Pipeline syntax

The pipeline syntax has changed, to become much more general and versatile.

The syntax before was:
```c
while {
// not yet in pipeline
// ...
{ /*stage 0*/ }
->
{ /*stage 1*/ }
->
{ /*stage 2*/ }
// no longer in pipeline
// ...
}
```
A new block was necessary after each arrow (`->`) operator, and before and
after the last block the instructions were outside of the pipeline.
The pipelining operator is now akin to the step operator `++:`, but with a
higher priority. Blocks are no longer necessary, which changes where the
pipeline is considered to start and end. So this above has to be rewritten as:

```c
while {
  // not yet in pipeline
  // ...
  {

  ->

  ->

  }
  // no longer in pipeline
  // ...
}
```

## [CL0004] While loops cycle rules

The state following a loop is now collapsed into the loop conditional whenever
possible, avoiding an extra cycle. This results in a more efficient usage of
cycles, and clarifies the while loop chaining rules. However, this can impact
the logic of existing code in cases such as follows:

```c
while (C) {
  A
}
B
```

Before, there would *always* be a cycle introduced upon exiting the loop, so
`B` would be in a different cycle than `A`. This also meant that there
would be an extra cycle between `C` becoming false, and `B` being reached.

Silice now automatically deals with such loops as if they were written as:
```c
while (1) {
  if (C) {
    A
  } else {
    B
    break;
  }
}
```
This means there is no extra cycle between `C` becoming false and `B` being
reached.

While it is generally favorable, this change may break some existing code.
To revert to the previous behavior, add a step operator as follows:

```c
while (C) {
  A
}
++: // added
B
```

## [CL0005] If-else cycle rules

Some if/else constructs are such that when taking one branch
what comes after the if/else is not reached.

For instance in a loop body:
```c
  if (C) {
    break;
  }
  N
```
If `C` is true, `N` is never reached. Before this was introducing a cycle
before `N`, which can actually be skipped by pulling `N` in the `else` part:
```c
  if (C) {
    break;
  } else {
    N
  }
```
This is now done automatically.
These optimizations cascade to successive if-s, for instance:
```c
  if (C1) { break; }
  if (C2) { break; }
  if (C3) { break; }
  N
```
Takes now only one cycle as the if-s and `N` are automatically nested
(versus 3 cycles before).
