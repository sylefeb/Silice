# Troubleshooting

## Linux

Cleaning up the RISC-V toolchain, before reinstalling
Silice dependencies: ```sudo apt remove *riscv64*```

openFPGALoader failing (cannot open usb) most likely a problem with rights on `/dev/ttyUSB0`: see [here](https://gist.github.com/sylefeb/f9da4abc7e930cb3fbd0c997e669b0dd)

## Windows

Driver problems: use [Zadig](https://zadig.akeo.ie/) to swap the board driver for WinUSB.
