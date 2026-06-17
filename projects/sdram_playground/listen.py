#!/usr/bin/env python3

# LLM assisted code
# Reviewed by @sylefeb

"""
Listen on a serial port and print received characters.
Usage: python listen_uart.py [port] [baud]
  port  — e.g. /dev/ttyUSB0, COM3   (default: /dev/ttyUSB0)
  baud  — 9600 or 115200            (default: 9600)
"""

import sys
import serial

PORT = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyUSB0"
BAUD = int(sys.argv[2]) if len(sys.argv) > 2 else 9600

try:
    with serial.Serial(
        port=PORT,
        baudrate=BAUD,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=1,
    ) as ser:
        print(f"Listening on {PORT} at {BAUD} baud (8-N-1) — Ctrl+C to quit\n")
        while True:
            byte = ser.read(1)      # blocks up to timeout seconds
            if byte:
                ch = byte.decode("ascii", errors="replace")
                # Print readable chars normally; show hex for anything else
                if ch.isprintable() or ch in ("\n", "\r", "\t"):
                    print(ch, end="", flush=True)
                else:
                    print(f"[0x{byte[0]:02X}]", end="", flush=True)

except serial.SerialException as e:
    print(f"Error opening {PORT}: {e}", file=sys.stderr)
    sys.exit(1)
except KeyboardInterrupt:
    print("\nDone.")
