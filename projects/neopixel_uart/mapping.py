import serial
import time
import sys
import os
import glob

if len(sys.argv) != 2:
  print("send.py <port>")
  sys.exit()

ser = serial.Serial(sys.argv[1],115200)

def send_byte(b):
  packet = bytearray()
  packet.append(b)
  ser.write(packet)
  for i in range(0,5):
    pass

send_byte(255) # reset

while True:
    for l in range(0,20):
      print("LED " + str(l))
      for j in range(0,20):
        packet = bytearray()
        send_byte(j)
        if j == l:
          if l == 0:
            send_byte(63)
            send_byte(63)
            send_byte(63)
          else:
            send_byte(0)
            send_byte(63)
            send_byte(0)
        else:
          send_byte(0)
          send_byte(0)
          send_byte(0)
      time.sleep(1)

ser.close()
