# LCD controller test

The controller is available [here](../common/lcd.ice).

Tested on the iCEstick (`make icestick`).

## Pinout for the iCEstick

See [connector pins layout](../../frameworks/boards/icestick/icestick.pcf).

| iCEstick | LCD 1602 |
|----------|----------|
| PMOD8    | E        |
| PMOD7    | RS       |
| PMOD4    | D7       |
| PMOD3    | D6       |
| PMOD2    | D5       |
| PMOD1    | D4       |

## Full schematic

> **Note:** The LCD 1602 we tested with expect a 5V input, but seem to be doing ok at 3.3V. However, the text may appear very faint. It may be necessary to pull the contrast pin (V0) to ground to see anything. You may also drive the LCD 1602 from a 5V source, in which case do not connect the FPGA +3.3V!

![](./ice40-schematic.png)

## Result

![](./hello-silice.jpg)
