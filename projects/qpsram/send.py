import serial
import time
import sys
import os
import glob

if len(sys.argv) != 4:
  print("send.py <port> <base> <file>")
  sys.exit()

addr = int(sys.argv[2], 0)
print("base address is ",addr)

ser = serial.Serial(sys.argv[1],500000, timeout=1)

totbytes = os.path.getsize(sys.argv[3])
f = open(sys.argv[3],"rb")

# send start tag
packet = bytearray()
packet.append(0xAA)
ser.write(packet)

# read ack
b = ser.read(1)
if len(b) == 0:
  print("\n[ERROR] acknowledgement not received, is this the correct port?")
  os._exit(-1)
else:
  i = int.from_bytes(b,byteorder='little')
  if i != 0x55:
    print("\n[ERROR] incorrect acknowledgement received, is this the correct port?")
    os._exit(-1)

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
  if n == 65536:
    ser.write(packet)
    ntot = ntot + n
    print("%.1f" % (ntot*100/totbytes),"% ")
    packet = bytearray()
    n = 0

ser.write(packet)

ser.close()
