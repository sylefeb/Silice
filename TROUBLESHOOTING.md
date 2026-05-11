# Troubleshooting

## Linux

- Cleaning up the RISC-V toolchain, before reinstalling
Silice dependencies: ```sudo apt remove *riscv64*```

- openFPGALoader failing (cannot open usb) most likely a problem with rights on `/dev/ttyUSB0`: see [here](https://gist.github.com/sylefeb/f9da4abc7e930cb3fbd0c997e669b0dd)

## Windows

Driver problems: use [Zadig](https://zadig.akeo.ie/) to swap the board driver for WinUSB.

## Windows WSL

### Program through USB:
Install usbipd-win. share and attach the peripheral following the instructions below (from https://learn.microsoft.com/fr-fr/windows/wsl/connect-usb )
- Install https://github.com/dorssel/usbipd-win/releases
- Open a Powershell with administrator rights.
- Run `usbipd list`, identify the `BUSID` of your board, also note its `VID:PID`.
- Run `usbipd bind --busid 10-4`, where `10-4` is replaced by your board `BUSID`.
- Run `usbipd attach --wsl --busid 10-4`, where `10-4` is replaced by your board `BUSID`.
- In WSL run `lsusb` you should see the `VID:PID` of your board.
- Fix the permissions by following this, with the correct usbid https://gist.github.com/sylefeb/f9da4abc7e930cb3fbd0c997e669b0dd

openFPGALoader should now work, try `openFPGALoader --scan-usb`

## Board-specific

### Gatemate evaluation board

VGA PMOD: set J14 (left to PMOD connectors) to 2.5V for the PMOD to worl (image
is otherwise distorted / undetected).

### Arty A7 (and Xilinx boards)
These require nextpnr-himbaechel with xilinx support enabled. See [tools/buildings/README.md](./tools/building/README.md) for help with building this version.
