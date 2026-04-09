# Troubleshooting

## Linux

Cleaning up the RISC-V toolchain, before reinstalling
Silice dependencies: ```sudo apt remove *riscv64*```

openFPGALoader failing (cannot open usb) most likely a problem with rights on `/dev/ttyUSB0`: see [here](https://gist.github.com/sylefeb/f9da4abc7e930cb3fbd0c997e669b0dd)

## Windows

Driver problems: use [Zadig](https://zadig.akeo.ie/) to swap the board driver for WinUSB.

## Windows WSL

Program through USB:
- Install usbipd-win. share and attach the peripheral following this https://learn.microsoft.com/fr-fr/windows/wsl/connect-usb
- List your peripherals WSL side to identify its usbid (e.g. 0403:6010)
- Fix the permissions by following this, with the correct usbid https://gist.github.com/sylefeb/f9da4abc7e930cb3fbd0c997e669b0dd
- openFPGALoader should now work, try `openFPGALoader --scan-usb`

## Gatemate evaluation board
- VGA PMOD: set J14 (left to PMOD connectors) to 2.5V
