# Dynamic warm boot on the ice40, proof of concept

**TL;DR** *I teamed up with @juanmard and @unaimarcor to explore the possibility of manipulating warm boot vector addresses dynamically, from a running design. And it works! You can now fit as many bitstreams as you can in SPI-flash, and dynamically reboot to any of them from a running design, for no more than the cost of updating 4KB of SPI-flash.*

## Warm boot?

If you are not familiar with the concept of *warm boot* on the ice40, do not worry, [read this tutorial first](../ice40-warmboot/README.md). I also recommend reading [@unaimarcor notes on the topic](https://umarcor.github.io/warmboot/).  

In the following I assume the reader is familiar with these basic ideas: 
- The ice40 can reboot itself and restart from any of four bitstreams store in SPI-flash. This is achieved using the Verilog vendor primitive `SB_WARMBOOT`.
- The addresses of the bitstreams are stored in a small table at the start of the SPI-flash. Let's call this the *header*.
- The header table has actually five entries, one for the bitstream to load upon reset, and four that can be dynamically selected when rebooting with `SB_WARMBOOT`.

This is great because writing a complete bitstream to SPI-flash is a relatively slow business, as they are relatively large (e.g. 32KB on IceStick, 105KB on IceBreaker. Also, `SB_WARMBOOT` allows a design to select which bitstream will be next from logic, paving the way to interesting effects, one being a bootloader menu to select between different designs.

## A bit of history

Normally, the warm boot is limited to the four bitstreams which addresses have been written down in the header.

About four years ago (I write this in 2021) @juanmard made a [special version of `iceprog`/`icemulti`](https://github.com/juanmard/icestorm/) that can pack more than four bitstreams and can re-arrange entries in the header efficiently. This is very useful, but one drawback is that you still have to plug your device to the computer to swap the bitstreams. But @juanmard was already thinking about how to hot-swap the addresses in the header from a running design.

A few days back, [I started to tinker with the Fomu](https://twitter.com/sylefeb/status/1387884320359165956) and we were [discussing some SPI-flash difficulties with @brunolevy01](https://twitter.com/sylefeb/status/1388038336300920833). This is when I first encountered [foboot](https://github.com/im-tomu/foboot) and `SB_WARMBOOT`, which @juanmard and @unaimarcor kindly explained to us!

I found the idea quite amazing and put together [the demo](https://twitter.com/sylefeb/status/1388586566591913985) and [tutorial](../ice40-warmboot/README.md) about `SB_WARMBOOT`. 

But then, as we were discussing with @juanmard, we decided to investigate the hot-swap idea further. Here we are!

## Hot-swapping addresses in the SPI-flash header

The principle is quite direct, but SPI-flash write requirements makes it a bit more interesting. 

In this proof of concept we will use only two entries of the header:
- The reset bitstream address, this will be a *bootloader*.
- The first bitstream address, which will be the address of the next design.

We do not need more, because we will dynamically rewrite the first bitstream address.

> **Note:** it might still be useful to use all four entries to avoid rewriting the header too often, which is far from free (more below).

Our goal is to make it so that the bootloader selects a new design to run, and when the design decides to stop it uses `SB_WARMBOOT` to go back to the bootloader. In turn, the bootloader selects the next design, and uses `SB_WARMBOOT` to reset to it. This loops back infinitely, chaining all designs with only the SPI-flash size as a hard limit. In this process, only the first bitstream address is used.

So, in the end, the only thing the bootloader has to do is to write a new address at the correct address in the SPI-flash header? Yes! But not so fast. There is a catch... 

As far as I know, to write to SPI-flash we first need to erase *the entire 4KB sector* containing the address we want to write to. We have only 3 bytes to change, but this will require us to:
- read the first 4KB of SPI-flash
- modify the three bytes
- clear the entire first 4KB
- write back the updated data

This also means we need 4KB of temporary memory ... This can be put in BRAM, but that is a lot of BRAM to spend. Instead, however, we can use the SPI-flash. In particular, we leave 4KB free somewhere (e.g. the end) to use as a *scratch pad*. This way we can:
1. copy the first 4KB of SPI-flash to another SPI-flash location and patch the address on the fly
2. clear the entire first 4KB sector
3. copy back the updated sector

The copy on step 1 uses only a small buffer, say 256 bytes. So we only have to patch the very first read segment. 

> **Note:** we could initialize the *scratch pad* to be the same as the first 4KB of SPI-flash so that we only ever read only the address to be changed. I have not done that in this POC, but that would avoid an entire 4KB read/write in step 1!

