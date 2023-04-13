# QPI-PSRAM writer and loader

This tool is used to store data from UART into SPRAM (Quad SPI).
Typically this would be used to put data in SPRAM before switching to a
design that expects this data to be there. As long as the badge has
power, the written data remains in SPRAM.

> Tested on the mch2022 badge, icebreaker and icestick with
> the [QQSPI pmod](https://machdyne.com/product/qqspi-psram32/).

___

To build the writer, run
```make <board> -f Makefile.write```

To send data, run
```python send.py <uart port> 0 <file>``` where `<uart port>` is
typically `/dev/ttyACM1` under Linux and e.g. `COM6` under Windows.

___

To build the reader, run
```make <board> -f Makefile.read```

To read data, run
```python get.py <uart port> 0``` where `<uart port>` is
typically `/dev/ttyACM1` under Linux and e.g. `COM6` under Windows.
