# Tips and tricks on using some boards

This is where we share tips and tricks on using certain boards under certains
systems. Feel free to contribute!

## Drivers under Windows

For many boards it is necessary to use a tool like [Zadig](https://zadig.akeo.ie/) to replace the default driver by the `WinUSB` driver. On some boards (e.g icebreaker) Zadig will report two interfaces. The first (Interface 0) is typically for programming (change the driver on this one) while the second (Interface 1) is for serial communication (leave it unchaged).

Needless to say, be a bit cautious when swapping drivers, in particular to not mistakenly change the driver of a different peripheral.

## ULX3S

Under Windows + MinGW64, openFPGALoader is used by default by Silice programming scripts. However it sometimes failed. When this happens, try `fujprog BUILD_ulx3s/build.bit` instead.

## Quartus for Altera FPGAs (de10nano, de2)

If Edalize fails complaining about `quartus_sh`, make sure to have the bin directory of the correct version of Quartus in the path.

For instance, for the de2 the default path would be `C:\altera\13.0sp1\quartus\bin64`, for the de10nano `C:\intelFPGA_lite\19.1\quartus\bin64`.

If the build fails after that, it might be best to go into the directory `BUILD_de2` (or `BUILD_de10nano`) and open the Quartus project (`build.qpf`). This lets you manually build in Quartus and see what could be wrong (e.g. missing device install, etc.). Regarding programming, I found this [video helpful](https://www.youtube.com/watch?v=K1k1VIAUSqI).
