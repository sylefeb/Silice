# I2S audio PCM demo

This design generates a pure tone (366 Hz sinewave) and sends it through the I2S protocol to a small PCM5102 audio DAC mounted on a breakout board. The board nicely fits directly in a PMOD, and costs around $10.

This example is prepared for the IceStick (but should be easy to adapt -- main thing to adjust being the base clock frequency).

<p align="center">
  <img src="audio_pcm.jpg">
</p>

## Testing

Solder the pins to the PCM5102 board and plug it into the PMOD, same as in the picture above. **Beware of the orientation** as a VCC mismatch could likely damage the board and/or the IceStick. Plugin a headset or some speakers, **bring the volume down**.

Then, from a command line in this directory enter:
```
make icestick
```

You should hear a pure [sinusoidal 366 Hz tone](https://szynalski.com/tone#366.21,v0.83). Why 366 Hz? See the source code ;)

## Source code

Everything is in [main.ice](main.ice), the source code is commented.

## Links

- soundwave generator https://www.szynalski.com/tone-generator/
- PCM5102 datasheet https://www.ti.com/lit/ds/symlink/pcm5102.pdf
