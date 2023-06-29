# SPI-flash reader

The designs here implement reading from SPI-flash using various modes. These are controllers both efficient for random access (trying to minimize latency as much as possible) and for streaming.

This is done by enabling Quad-SPI (QSPI mode) and continuous read (so that commands don't have to be resent every read), and using a DDR clock so that the SPI-flash runs at the same frequency as the host.

> **IMPORTANT:** Enabling QSPI puts the flash in a special mode that can prevent further programming. So if a bitstream enabling QSPI is programmed on flash and loaded on power up everytime, it might seem that your board is bricked (or has a dammaged flash). There's a solution!
> - On the icebreaker this should be no problem with the latest *iceprog*, but in case of trouble know that there is a jumper called CRESET on the board. By closing the jumper you can prevent the current bitstream to load from flash. This will leave the flash in normal SPI state so you can reprogram.
> - On the ULX3S the flash might become inaccessible to fujprog and openFPGALoader. But fear not, there is a small bitstream in the `bitstreams` subdirectory here that you can program onto the board (via SRAM) to exit QSPI. After programming with `fujprog bitstreams/ulx3s_exit_qspi.bit` you can again program the flash with e.g. `fujprog -j flash mydesign.bit`.

The QSPI controllers in this directory have been developped on ice40 UP5K (icebreaker board more specifically), but the *spiflash2x* design also works fine on ECP5 (tested on ulx3s).

The main controller designs are:
- [spiflash2x.si](spiflash2x.si), where 2x refers to the fact that the controller runs typically at 50MHz on the icebreaker with the main design at 25MHz.
- [spiflash4x.si](spiflash4x.si), where 4x refers to the fact that the controller runs typically at 100MHz on the icebreaker with the main design at 25MHz. **This design is not stable as the result vary with place and route 'luck' (nextpnr random seed)**.

> **NOTE:** these controller will likely become deprecated in the future as I move towards merging them with the [QPSRAM controller](../qpsram/README.md).

## Test design

The test design simply reads some bytes from SPI-flash and sends them over UART.

To test, build and program with e.g.

> make icebreaker

## Links

- For Verilog SPI-flash/ram controllers fine tuned for the icebreaker I highly recommend @smunaut's work, see e.g. [no2qpimem](https://github.com/no2fpga/no2qpimem/tree/master/rtl)
