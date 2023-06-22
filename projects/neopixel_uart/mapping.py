import serial
import time
import sys
import os
import glob

if len(sys.argv) != 2:
  print("send.py <port>")
  sys.exit()

ser = serial.Serial(sys.argv[1],1152000) #576000)
packet = bytearray()

def push_byte(b):
  packet.append(b)

push_byte(255) # reset
ser.write(packet)
packet = bytearray()

n = 678*4
frame = 0

#while True:
push_byte(255) # reset
for l in range(0,n):
  # print("LED " + str(l))
  if n < 678:
    push_byte(5)
    push_byte(0)
    push_byte(0)
  elif n < 678*2:
    push_byte(0)
    push_byte(5)
    push_byte(0)
  elif n < 678*3:
    push_byte(0)
    push_byte(0)
    push_byte(5)
  else:
    push_byte(1)
    push_byte(0)
    push_byte(1)
ser.write(packet)
packet = bytearray()
push_byte(255) # reset
frame = frame + 1

ser.close()
