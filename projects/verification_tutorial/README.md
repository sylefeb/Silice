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

<!-- Describe implemented features (#assert, #assume, #restrict, #cover, #wasat, #stable, #stableinput, #mode, #depth, #timeout, algorithm#) -->
## Syntax and semantics

### Immediate assertions (`#assert`)

### Assumptions and restrictions (`#assume`, `#restrict`)

### Path assertions (`#wasin`)

### Stability checking (`#stableinput`, `#stable`)

### Cover tests (`#cover`)

### Algorithm meta-specifiers (`#mode`, `#depth`, `#timeout`)

<!-- Introduce the formal board, what it does, how it is useful -->
## Easy verification with the formal board

<!-- Some quick examples of verification -->
## Examples
