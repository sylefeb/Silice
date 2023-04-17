import serial
import time
import sys
import os
import glob

if len(sys.argv) < 4:
  print("xfer.py <port> <r|w> <addr> <size|file>")
  sys.exit()

# open serial port
ser = serial.Serial(sys.argv[1],500000, timeout=1)

# op to perform
op = sys.argv[2]
if op == 'w':
  print("writing")
elif op == 'r':
  print("reading")
else:
  print("unknown command ",op)
  os.exit(-1)

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
packet = bytearray()
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
elif op == 'w':
  # send data
  packet = bytearray()
  n = 0
  ntot = 0
  while True:
    b = f.read(1)
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
