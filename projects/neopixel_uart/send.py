import serial
import time
import sys
import os
import glob

remap = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19]

if len(sys.argv) != 3:
  print("send.py <port> <directory>")
  sys.exit()

ser = serial.Serial(sys.argv[1],115200)

while True:
  files = glob.glob(sys.argv[2] + "/*.col")
  for fname in files:
    f = open(fname,"r")
    packet = bytearray()
    packet.append(255) # reset
    ser.write(packet)
    lines = f.readlines()
    for l in lines:
      # print(l)
      which = 0
      for n in l.split():
        packet = bytearray()
        if which == 0:
          if int(n) < len(remap):
            v = remap[int(n)]
          else:
            v = int(n)
        else:
          v = int(float(n)*63)
        which = which + 1
        # print("val = " + str(v))
        packet.append(v)
        ser.write(packet)
      # wait some time
      for i in range(0,50000):
        pass

ser.close()
