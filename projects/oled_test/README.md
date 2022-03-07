# OLED/LCD controller library test

[OLED/LCD controller library](../common/oled.si).

Tested on:
- the ULX3S
- the IceStick

The pinout for the IceStick is:
| IceStick        | OLED      |
|-----------------|-----------|
| PMOD10 (pin 91) | din       |
| PMOD9  (pin 90) | clk       |
| PMOD8  (pin 88) | cs        |
| PMOD7  (pin 87) | dc        |
| PMOD1  (pin 78) | rst       |

For the ULX3S simply use the connector just below the FPGA, following the proposed pinout (labels on the board).
