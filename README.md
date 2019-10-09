# Silice

Silice aims at simplifying writing code for FPGAs. It compiles to and inter-operates with Verilog. Silice is not meant to hide the HDL complexity, but rather to complement it, making it more enjoyable to write parallel code and algorithms utilizing the FPGA architecture. A basic understanding of Verilog is highly recommended as a pre-requisite to using Silice.

Example:
```c
algorithm main(output uint8 led) {   
  uint20 counter = 0; // a 20 bits unsigned integer
  led := counter;     // LEDs track the 8 least significant bits  
  while (1) {         // forever
    counter ++;       // count
  }  
}
```
