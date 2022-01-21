import serial
import time
import sys

if len(sys.argv) != 3:
  print("send.py <port> <file>")
  sys.exit()

ser = serial.Serial(sys.argv[1],115200)

f = open(sys.argv[2],"r")
lines = f.readlines()
for l in lines:
  # print(l)
  which = 0
  for n in l.split():
    packet = bytearray()
    if which == 0:
      v = int(n)
    else:
      v = int(float(n)*63)
    which = which + 1
    # print("val = " + str(v))
    packet.append(v)
    ser.write(packet)

ser.close()
