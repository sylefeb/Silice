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
#  for i in range(0,5):
#    pass

send_byte(0)
send_byte(0)
send_byte(0)
send_byte(0)

send_byte(255) # reset
send_byte(255) # reset
send_byte(255) # reset
send_byte(255) # reset
send_byte(255) # reset
send_byte(255) # reset
send_byte(255) # reset
send_byte(255) # reset
print("----")
# time.sleep(1.0)

# n = 678
n = 1300

for l in range(0,n):
  print("LED " + str(l))
  send_byte(l>>8)
  send_byte(l&255)
  if l >= 940:
    send_byte(7)
    send_byte(7)
    send_byte(7)
  else:
    send_byte(0)
    send_byte(3)
    send_byte(0)
  # time.sleep(0.1)

ser.close()
