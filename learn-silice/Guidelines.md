# Optimizing Silice designs

Silice offers flexibility and ease of prototyping. But ultimately, when your design prototype works well you will start looking into efficiency. This often boils down to two things:
- Max achievable frequency
- Design size (in terms of FPGA resources, e.g. LUTs)

Optimizing your designs for size and frequency is a difficult art form, whether it is in Silice or Verilog. It is also very exciting and rewarding. Be warned, you might end up entirely rewriting your design in a different style. However, you can do so without leaving the comfort of Silice.

These guidelines are here to help you reduce your design size and increase max frequency. 

## Making designs more efficient

If you haven't already, I recommend that you watch the [Silice introductory video](https://www.youtube.com/watch?v=_OhxEY72qxI). In particular, it is important to understand that Silice builds a circuit for you, and this circuit will generate additional costs.

The good news is that there are ways to reduce this cost, and I have had some success in writing designs which compactness is similar to that of optimized Verilog, albeit to be fair still a bit bigger / slower max freq. But I am chasing inefficiencies! My goal is to ensure that yes, it is possible to write efficient designs in Silice. Note that I am not saying it will be *easy* and certainly not *easier* than e.g. writing pure Verilog.

Silice has only few layers of abstraction: the flip-flops are automatically generated (and culled when not required), and a state machine is produced based on flow control constructs -- not always, this depends on the use of the `++:` operator, `while` loops, etc. Larger state machines increase the design size and lower the max frequency. However, a design principle of Silice is that the rules are explicit about when states are introduced [please refer to the documentation](Documentation.md). In the future, more analysis will be available to report these costs.

For general FPGA design rules see [this post](http://www.fpgacpu.org/log/sep00.html#000919). The gist of it is to favor simplicity of code, which often translates to efficient designs. 

To make a design more efficient, we first and foremost want to reduce the need for multiplexers. These are expensive in terms of routing, and interconnect is a major factor in a lower max frequency on an FPGA. This implies:
- Restrict conditionals only where really necessary: it is better to update a variable if this has no effect, rather than trying to not do it. This is very different from CPU programming: we attempt to minimize logic, circuit depth and interconnect.
- Reread the [notes on algorithms calls, bindings and timings](AlgoInOuts.md) and in particular the timing section, check your algorithms bindings. Do not hesitate to introduce latency through registered inputs/outputs, this often helps fmax greatly.
- Reduce simple algorithms into a single loop (`while(1)` or `always`) that executes in a single cycle
- Explore the balance around the number of steps in algorithms (operator ++:). Having less steps simplifies the state machine multiplexers. Having more steps can improve fmax by doing less within each cycle (this is a matter of circuit depth, many non-interdependent small circuits in parallel is fine).
- Use `uninitialized` or power up initialization (`uint8 v(0);`) as much as possible.
- Within a cycle avoid reading a variable after updating it unless necessary, e.g. prefer
```c
  if (a == 0) { ... } // the test uses the value from previous cycle, fast
  a = a + 1;
```  
to 
```c
  a = a + 1;
  if (a == 0) { ... } // the test uses the updated value and is after the +1 circuitry, slower
```
if that is all the same in the end.
- Make your integers as tight as possible, favor bit manipulation, beware that comparisons involve an adder (e.g. a less than `<` test requires a subtraction, to end a loop favor `==`). Multipliers and shifters can require a significant size.
- Some operations can be split over multiple cycles to reduce design size; for instance a shift `<< N` can be done in shifts of `<< 1` over N cycles for a much smaller circuit.
- Use micro-coding for initialization sequences: build a tiny processor that reads instructions in a BRAM (**TODO** example with OLED)
- The max frequency can often be increased by paying in latency, ensuring less is done at each cycle. 
- Using <:: for bindings is one way to add latency, as algorithms will see the new input only at next clock posedge. See also [algorithm inputs and outputs timings](AlgoInOuts.md).

And again, keep that in mind: everything you put in your design is always there, up and running. If you attempt to not do something you are adding complexity (typically a multiplexer). Each time you introduce a condition, ask yourself whether it is truly necessary for proper operation, otherwise skip it.
