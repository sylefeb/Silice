# Streaming audio from an sdcard with Silice (DIY FPGA wave player!)

**Note:** This example is designed for the ULX3S board, but could be easily adapted to other boards having a sdcard slot and audio DAC (de10nano + IO board, I am looking at you!).

## How to build

Save a raw audio file, for instance from [Audacity](https://www.audacityteam.org/):
- 44100 Hz
- no header
- 8 bits signed PCM

From Audacity, record something or open a wav file, convert to mono, then select `File -> Export -> Export audio`. In the dialog that opens, select `Other uncompressed files` in front of `Save as type` and in `Format Options`, select `Header` = `RAW (header-less)`, and `Encoding` = `Signed 8-bit PCM`.

Save in a file named `track.raw`.

You can also use `ffmpeg`, with this command line: ` ffmpeg.exe -i input.mp3 -ac 1 -f s8 track.raw`.

Write the file `track.raw` on the sdcard, using a low-level write (e.g. Win32DiskImager under Windows). 

**Important:** all pre-existing data on the sdcard will be lost!

Put the sdcard in the ULX3S (and don't forget to plug speakers ;-) ).

Then plug your board in a USB port, open the command line in this folder and type `make ulx3s`.

## What's going on?

The wave data is streamed from the sdcard at the correct sampling rate and sent to the audio port.

Streaming is achieved in `main` by the use of the `sdcard_streamer` algorithm. This algorithm
talks to the sdcard and sends us back one byte at a time, transparently reading sectors. (I won't dive into details now, this is for a future tutorial. But if you are curious have a look at the [source code](../common/sdcard_streamer.ice)).

We talk to the streamer through an *interface*: `streamio stream`. This is a very handy concept of Silice, 
allowing to group and bind multiple I/O in a same variable.

Note that the streamer outputs an unsigned byte in `stream.data`. However we know this value is signed
as we saved as 8-bit PCM. The signed oscillations go from -128 to 127, when we want oscillations between 0 and 255.
To convert the wave we use an *expression tracker*:
```c
  // tracker to convert to unsigned
  uint8 wave := {~stream.data[7,1],stream.data[0,7]}; // NOTE: a nice trick, flipping the sign 
                                                      // bit to remap [-128,127] to [0,255]
```
It inverts the bit sign to obtain the desired ramp. And yes, this works! -128 (`10000000`) maps to 0,
-1 (`11111111`) maps to 127, 127 (`01111111`) maps to 255. Quite a nice trick<sup>[1](#footnote1)</sup>.

As `wave` is tracking `stream.data`, it always reflects its (sign modified) latest value.
The signal is not directly sent to the audio pins `audio_l` and `audio_r`. Instead, it is fed
into another algorithm, `audio_pwm`: this algorithm maps the 8-bits of the wave to the 4-bits audio
DAC of the ULX3S board. 

Why? We could send only the high bits of the signal, but we would loose a lot of data (and subtle audio)
in the process. Instead, `audio_pwm` makes the signal nicer by relying on another cool trick<sup>[1](#footnote1)</sup>: a PWM that oscillates between the two 4-bits values to artificially increase the resolution.

The idea is to produce a rectangular [PWM signal](https://en.wikipedia.org/wiki/Pulse-width_modulation), 
between two 4-bits values, for instance 5 and 6. 
If the signal spends half its time on 5 and half on 6, then the output will be a halfway voltage,
exactly what we want! Since we can drive the output much (much!) faster than the 44100 Hz with our 25000000 Hz clock, we
can easily afford this trick.

The implementation is in `audio_pwm`:

```c
algorithm audio_pwm(
  input  uint8 wave,
  output uint4 audio_l,
  output uint4 audio_r,
) <autorun> {
  
  uint4  counter        = 0;           // 4-bit counter to track the PWM proportion
  uint4  dac_low       := wave[4,4];   // tracks higher bits
  uint4  dac_high      := dac_low + 1; // same plus on (we interpolate between dac_low and dac_high)
  uint4  pwm_threshold := wave[0,4];   // threshold for pwm ratio, using lower bits
                                       //   threshold == 0 => always low, threshold == 15 almost always high
  
  always {
  
    if (counter < pwm_threshold) {
      audio_l = dac_high;
      audio_r = dac_high;
    } else {
      audio_l = dac_low;
      audio_r = dac_low;
    }
  
    counter = counter + 1;
 
  }
}
```

Finally, the main loop has a very simple job: requesting the next byte from the sdcard at the correct sampling rate (44100 Hz). Here is the loop:

```c
  uint23 to_read = 0;
  while (1) {
    
    uint16 wait = 1;
    
    // request next
    stream.next     = 1;  
    
    // wait for data
    while (stream.ready == 0) { 
      wait = wait + 1;  // count cycles
    }

    // wait some more (until sampling rate is correct)
    while (wait < $base_freq // track_freq$) { 
      wait = wait + 1;  // count cycles
    }
    
    // leds for fun
    leds    = (wave > 230 ? 8h88 : 0) | (wave > 192 ? 8h44 : 0) | (wave > 140 ? 8h22 : 0) | (wave > 130 ? 8h11 : 0);
    
    // next
    to_read = to_read + 1;
  }
```

And that's it!

A few other notes:
- Try by-passing the `audio_pwm` algorithm, writing only `wave[4,4]` in `audio_l` and `audio_c`. The quality drops horribly!
- `$base_freq // track_freq$` is preprocessor code computing the number of wait cycles for the base clock (25 MHz) to achieve the target sampling rate (44.1 kHz). `//` is the integer division in Lua (the language used by the preprocessor).
- The base frequency and wave frequency are defined at the top of [main.ice](main.ice): `$$base_freq  = 25000000` and `$$track_freq =    44100`.
- It will happily read data past your file, you may get screeching sounds!

<a name="footnote1">1</a>: I got these audio tricks [from @emard](https://github.com/emard/ulx3s-misc/blob/master/examples/audio/hdl/dacpwm.v).

## Future work

Turn this into an audio player with an OLED screen. Silice already has all the components!

## Known issues

The sdcard has to be a SDHC. Also it sometimes fails to initialize. In such cases I first try to reset (press PWR, top right of the ULX3S). If that still fails I remove it carefully, wait a second, a re-insert it. You can also try to flash the design (`fujprog -j flash BUILD_ulx3s/built.bit`) as it usually works on power-up.
