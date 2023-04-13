import serial
import time
import sys
import os
import glob

if len(sys.argv) != 3:
  print("get.py <port> <base>")
  sys.exit()

addr = int(sys.argv[2], 0)
print("base address is ",addr)

ser = serial.Serial(sys.argv[1],115200, timeout=1)

# send start tag
packet = bytearray()
packet.append(0xAA)
ser.write(packet)

# send address
packet = bytearray()
packet.append((addr>>16)&255)
ser.write(packet)

packet = bytearray()
packet.append((addr>>8)&255)
ser.write(packet)

packet = bytearray()
packet.append(addr&255)
ser.write(packet)

# read data
i = 0
ba = bytearray()
while True:
  b = ser.read(1)
  if len(b) == 0:
    break
  print("{:02X}".format(int.from_bytes(b,byteorder='little')),end=" ")
  ba.append(int.from_bytes(b,byteorder='little'))
  i = i + 1
  if i == 16:
    i = 0
    print(" ",bytes(ba))
    ba = bytearray()
