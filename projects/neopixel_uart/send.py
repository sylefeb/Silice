import serial
import time
import sys
import os
import glob
import sys

if len(sys.argv) < 3:
  print("send.py <port> <led map (optional)")
  sys.exit()

map = []

if len(sys.argv) > 2:
  file_map = sys.argv[2]

  nb_led = 0
  f = open(file_map, 'r')
  line = f.readline()
  while line:
    if (line[0:1] == '#'):
      print(line)
    else:
      nb_led = nb_led+1
    line = f.readline()
  f.close()

  for i in range(0, nb_led):
    map.append(0)

  f = open(file_map, 'r')
  line = f.readline()
  while line:
    if (line[0:1] == '#'):
        print(line)
    else:
        lin =  line.split("\n")[0]
        sline = lin.split(" ")
        ind = int(sline[1])
        val = int(sline[0])
        map[ind]=val
    line = f.readline()
  f.close()


ser = serial.Serial(sys.argv[1],115200)

def send_byte(b):
  packet = bytearray()
  packet.append(b)
  ser.write(packet)
  for i in range(0,5):
    pass

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

while True:
  for line in sys.stdin:
    if line[0] == '$':
      line   = line[1:]
      values = [int(n) for n in line.split()]
      if len(map) > 0:
        v = map[values[0]]
      else :
        v = values[0]
      packet = bytearray()
      packet.append(v>>8)
      packet.append(v&255)
      packet.append(values[2])
      packet.append(values[1])
      packet.append(values[3])
      ser.write(packet)
ser.close()
