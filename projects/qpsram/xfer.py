# @sylefeb 2023
# https://github.com/sylefeb/Silice
# MIT license, see LICENSE_MIT in Silice repo root

import serial
import sys
import os

if len(sys.argv) < 4:
  print("xfer.py <port> <r|w> <addr> <size|file>")
  sys.exit()

# open serial port
# ser = serial.Serial(sys.argv[1],500000, timeout=1)
ser = serial.Serial(sys.argv[1],115200, timeout=1)

# op to perform
op = sys.argv[2]
if op == 'w':
  print("writing")
elif op == 'r':
  print("reading")
elif op == 'b':
  print("reboot")
else:
  print("unknown command ",op)
  sys.exit()

# if boot, send it now
packet = bytearray()
if op == 'b':
  packet.append(0xE5)
  ser.write(packet)
  sys.exit()

# address
addr = int(sys.argv[3], 0)
print("base address is ",addr)

# size or file
if op == 'r':
  size = int(sys.argv[4], 0)
elif op == 'w':
  size = os.path.getsize(sys.argv[4])
  f = open(sys.argv[4],"rb")
print("size is         ",size)

# send start tag
if op == 'w':
  packet.append(0xD5)
else:
  packet.append(0x55)
ser.write(packet)

# send address
packet = bytearray()
packet.append((addr>>24)&255)
packet.append((addr>>16)&255)
packet.append((addr>>8)&255)
packet.append(addr&255)
ser.write(packet)

# send size
# we report a size of one less (avoids a 32 bits -1 in logic)
size_m1 = size - 1
packet = bytearray()
packet.append((size_m1>>24)&255)
packet.append((size_m1>>16)&255)
packet.append((size_m1>>8)&255)
packet.append(size_m1&255)
ser.write(packet)

if op == 'r':
  f = open('read.bytes', 'wb')
  # read data
  i = 0
  ba = bytearray()
  while True:
    b = ser.read(1)
    if len(b) == 0:
      break
    f.write(b)
    print("{:02X}".format(int.from_bytes(b,byteorder='little')),end=" ")
    ba.append(int.from_bytes(b,byteorder='little'))
    i = i + 1
    if i == 16:
      i = 0
      print(" ",bytes(ba))
      ba = bytearray()
  f.close()
elif op == 'w':
  # send data
  packet = bytearray()
  n = 0
  ntot = 0
  while True:
    b = f.read(1) # this is really slow!
    if not b:
      break
    packet.append(int.from_bytes(b,byteorder='little'))
    n = n + 1
    if n == 32768:
      ser.write(packet)
      ntot = ntot + n
      print("%.1f" % (ntot*100/size),"% ")
      packet = bytearray()
      n = 0
  ser.write(packet)

ser.close()
