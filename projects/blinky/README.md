# Blinky

*The "Hello world" of FPGAs*

This is a small blinky written in Silice. It is the base test that runs on all boards, using only the onboard LEDs.

Blinky also provides a small and brief introduction to some basic Silice syntax. Let us have a look at the source code and discuss some aspects of it:

```c
algorithm main(output uint$NUM_LEDS$ leds) // $NUM_LEDS$ is replaced by the preprocessor,
{                                          // e.g. this becomes uint5 if NUM_LEDS=5
  uint28 cnt = 0; // 28 bits wide unsigned int
  
  // leds tracks the most significant bits of the counter
  leds := cnt[ widthof(cnt)-widthof(leds) , widthof(leds) ];

  while (1) { // forever 
    cnt  = cnt + 1; // increase cnt (loops back to zero after overflow)
  }
}
```

Let's consider some of the syntax:
- `cnt[ widthof(cnt)-widthof(leds) , widthof(leds) ]` is selecting bits of `cnt`. The syntax is `<var>[<first bit>,<width>]` so for instance `cnt[0,6]` are the six least significant bits of `cnt` while `cnt[20,8]` are the eight most significant bits of `cnt`. `widthof(cnt)` returns the width of the variable at compile time, here `28`. So for the case of `NUM_LEDS=5` and `uint28 cnt` this becomes `cnt[23,5]`, selecting the 5 most significant bits of `cnt`. As `cnt` is increased, these are the bits varying the least.
- `leds := ...` indicates that `leds` should be assigned the selected bits of `cnt` at every clock cycle. This happens before anything else. In this example, it would be functionally equivalent to having written:
   ```c
   algorithm main(output uint$NUM_LEDS$ leds)
   {
     uint28 cnt = 0;
     while (1) {
       leds = cnt[ widthof(cnt)-widthof(leds) , widthof(leds) ];
       cnt  = cnt + 1;
     }
   }
   ``` 
   In hardware, however, there is a difference and using `:=` leads to a simpler circuit, as it does not need to distinguish between being before the `while` statement or being inside it.
   