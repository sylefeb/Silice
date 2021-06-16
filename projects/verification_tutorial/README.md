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
- [Verifying designs written in Silice](#verifying-designs-written-in-silice)
    - [Table of contents](#table-of-contents)
    - [Prerequisites](#prerequisites)
        - [Verification methods](#verification-methods)
            - [Bounded Model Checking (BMC)](#bounded-model-checking-bmc)
            - [Temporal k-induction](#temporal-k-induction)
        - [Programs needed](#programs-needed)
    - [Syntax and semantics](#syntax-and-semantics)
        - [Immediate assertions (`#assert`)](#immediate-assertions-assert)
        - [Assumptions and restrictions (`#assume`, `#restrict`)](#assumptions-and-restrictions-assume-restrict)
        - [Path assertions (`#wasin`)](#path-assertions-wasin)
        - [Stability checking (`#stableinput`, `#stable`)](#stability-checking-stableinput-stable)
        - [Cover tests (`#cover`)](#cover-tests-cover)
        - [Algorithm meta-specifiers (`#mode`, `#depth`, `#timeout`)](#algorithm-meta-specifiers-mode-depth-timeout)
    - [Easy verification with the formal board](#easy-verification-with-the-formal-board)
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

![](./bmc.png)

#### Temporal k-induction

A temporal k-induction is the opposite of the spectrum compared to the BMC. It states that, for any valid state `s`,
it must be preceded by a sequence of maximum `k` valid states.

![](./tind.png)

### Programs needed

Symbiyosys is a front-end for Yosys to make formal verification easier.
As such, you will also need Yosys, which you can get [here](https://github.com/YosysHQ/yosys).
Note that, if you choose to build it yourself, you may need to create a symlink for yosys-abc,
depending on whether you installed it with yosys or on its own (because some programs expect a `yosys-abc` executable,
which isn't created if you have an external ABC solver).
You can get Symbiyosys [here](https://symbiyosys.readthedocs.io/en/latest/).

You will also need the SMT solver Yices2, which is available [here](https://yices.csl.sri.com/).
This solver handles BMC and cover tests quite fine, and fast enough (compared to e.g. z3).

<!-- Describe implemented features (#assert, #assume, #restrict, #cover, #wasat, #stable, #stableinput, #mode, #depth, #timeout, algorithm#) -->
## Syntax and semantics

In this section, we will describe the implemented features for design verification.
All of these features can be used in special `algorithm#`s.

An `algorithm#` is a normal algorithm (it can be instantiated like a normal one) that is necessarily written in the output file,
with a `formal_` prefix (the formal board will try to generate tests for all `algorithm#` in the design).
Because of the potential size overhead (potential because Yosys may optimize those away if they are not instantiated),
it is usually a good idea to surround those algorithms with `$$if FORMAL` blocks.
The `FORMAL` macro is automatically defined when using the formal board.

Be also aware that all the features described above are not necessarily synthesizable, leading to errors like this if some remain[[1]](#ref-1):

> ```
> 2.3.2. Executing AST frontend in derive mode using pre-parsed AST for module `\M_main'.
> Generating RTLIL representation for module `\M_main'.
> build.v:0: Warning: System task `$display' outside initial block is unsupported.
> build.v:0: ERROR: Can't resolve task name `\assert'.
> ```

### Immediate assertions (`#assert`)

Immediate assertions allow specifying conditions that must be satisfied (= evaluates to a true value) where the assertions lies.
Failure to satisfy the condition yields an error, which can be understood using the VCD trace generated by Symbiyosys.

An immediate assertions is declared using the `#assert(<condition>);` syntax, where `<condition>` is any allowed expression.
It can be used anywhere an instruction is allowed (at the top-level, in an `always` block, in control-flow blocks, etc).

### Assumptions and restrictions (`#assume`, `#restrict`)

Assumptions allow specifying side conditions which either are disallowed or should not be considered as reachable states.
Dividing by 0 is a good example of such condition.
Failure to satisfy an assumption *may* yield an error, but most of the time the path will simply not be taken in account.

There are two constructs for assumptions: `#assume(<condition>);` and `#restrict(<condition>);`.
Use `#assume` when any following `#assert` depends on it, otherwise use `#restrict` when it's just to help with the verification process.

### Path assertions (`#wasin`)

Sometimes, you need to verify whether the algorithm was in a specific state `N` cycles before.
Using named blocks (labels really), the `#wasin(<label>, <integer>)` construct allows checking whether the FSM index was 
the FSM index of `<label>` `<integer>` cycles before (defaults to 1 if not specified).

### Stability checking (`#stableinput`, `#stable`)

Ensuring that an expression does not change value in a specific state may be required, e.g. when designing a SDRAM arbiters
(when transvasing data from outside to inside the SDRAM, it must remain constant in the bus, otherwise causing trouble).

There are two kinds of stability checks: `#stable(<expr>)` and `#stableinput(<identifier>)`.
A `#stable` check asserts that a given expression does not change value in a given state (or never if in an `always` block),
whereas a `#stableinput` check assumes that an algorithm input does not change throughoutt its execution.
Because inputs are not registered, this is very useful to prevent from some side effects due to uncontroled mutability,
which would not necessarily happen when “normally” using a Silice algorithm.

### Cover tests (`#cover`)

### Algorithm meta-specifiers (`#mode`, `#depth`, `#timeout`)

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

<!-- Some quick examples of verification -->
## Examples

This directory contains several example of verifying code, for different algorithms:

- [divint_verif.ice](./divint_verif.ice) verifies some properties of integral division (the division used can be replaced quite easily)
- [mulint_verif.ice](./mulint_verif.ice) verifies some properties of integral multiplication

You can run the verification process using the provided [Makefile](./Makefile), by simply running the command
`make file`, where `file` is the file without the `.ice` extension you want to run the whole process on.

--------------------

<a name="ref-1"></a>[1]: This example was compiled:

``` c
algorithm main(output uint8 leds)
{
    __display("OK");
    #assert(1);
}
```
