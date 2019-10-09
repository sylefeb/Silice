# Silice

Silice aims at simplifying writing code for FPGAs. It compiles to and inter-operates with Verilog. Silice is not meant to hide the HDL complexity, but rather to complement it, making it more enjoyable to write parallel code and algorithms utilizing the FPGA architecture. A basic understanding of Verilog is highly recommended as a pre-requisite to using Silice.

Example:
```c
algorithm main(input uint1 button,output uint1 led) {  
  led := 0;
  while (1) {
    if (button == 1) {
      led = 1;
    }
  }  
}
```
