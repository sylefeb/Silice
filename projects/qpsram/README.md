# QPI-PSRAM writer and loader

This is a small design to help store and read data from PSRAM (Quad SPI) through UART.

Typically this would be used to put data in PSRAM before switching to a
design that expects this data to be there. As long as the board has
power, the written data should remain in PSRAM.

> Tested on the mch2022 badge (built-in PSRAM), and with the [QQSPI pmod](https://machdyne.com/product/qqspi-psram32/) from @machdyne on icebreaker, icestick, ulx3s and ecpix5.

> Prebuild bitstreams are in `bistreams` for the QQPSI pmod (use PMOD1 on icebreaker, PMOD2 on ecpix5, gp/gn 14 to 17 on ulx3s).

<p align="center">
  <img width="300" src="icestick_qqspi.jpg">
</p>

___

To build, run
```
make <board>
```

To send data, run
```
python xfer.py <uart port> w <offset> <file>
```
where `<uart port>` is
typically `/dev/ttyACM1` under Linux and e.g. `COM6` under Windows.
`offset` is the address where to store in PSRAM and `file` is the data file.

To read data, run
```
python xfer.py <uart port> r <offset> <size>
```
where `<uart port>` is
typically `/dev/ttyACM1` under Linux and e.g. `COM6` under Windows.
`offset` is the address where to store in PSRAM and `size` is the number of byte to read. The received data is displayed in the console.

<p align="center">
  <img width="350" src="example.jpg">
</p>

___

## Limitations

- If the transfer is interrupted (e.g. CTRL-C) the design will end up in an undetermined state. Simply reprogram the board.
- When experimenting with QPI it can happen that interrupted or wrong commands put the PSRAM in a state that cannot be easily recovered from. In such cases unplug the board, plug again, reprogram (keep in mind the PSRAM is *not* reset when reprogramming the FPGA).
