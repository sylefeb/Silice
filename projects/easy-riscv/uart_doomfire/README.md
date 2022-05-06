# UART Doom fire using Silice RISC-V integration

To try it, plug your board and do `make icestick` or `make icebreaker` (for other boards the PLLs/frequency need to be adjusted).

UART frequency is set to 921600, quite high so that the refresh is acceptable (but still too slow!).

I was able to connect using a Putty terminal, worked right out of the box. This requires a terminal supporting ANSI RGB color codes.
