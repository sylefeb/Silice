# @sylefeb 2023
# https://github.com/sylefeb/Silice
# MIT license, see LICENSE_MIT in Silice repo root

import serial
import sys
import random
import time
import math
from tqdm import tqdm

read_packed_size = 32

if len(sys.argv) < 4:
  print("memtest.py <port> <addr> <size>")
  sys.exit()

# open serial port
# ser = serial.Serial(sys.argv[1],500000, timeout=1)
ser = serial.Serial(sys.argv[1],115200, timeout=1)

# address
addr = int(sys.argv[2], 0)
print("base address is ",addr)

# size
size = int(sys.argv[3], 0)
size = math.ceil(size / read_packed_size) * read_packed_size

# seed
S = int(time.time())
# S = 42

if True:
  # send start tag
  packet = bytearray()
  packet.append(0xD5) # write
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

  # send data (pseudo random)
  print('Sending ...')
  packet = bytearray()
  n      = 0
  ntot   = 0
  pbs = tqdm(total=size)
  random.seed(S)
  while True:
    b = random.randint(0,255)

    if n % 2 == 0:
      b = 0x55
    else:
      b = 0xAA

    packet.append(b)
    n = n + 1
    if n == 32768 or ntot+n == size:
      ser.write(packet)
      pbs.update(n)
      packet = bytearray()
      if ntot+n == size:
        break
      ntot = ntot + n
      n = 0
  pbs.close()

# ------------- read back data

# send start tag
packet = bytearray()
packet.append(0x55) # read
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

print('Reading back ...')
n = 0
error = 0
pbr = tqdm(total=size)
rb = []
while n != size:
  bs = ser.read(read_packed_size)
  if len(bs) == 0:
    print("**************************************")
    print("**************************************")
    print("\033[91m" + f'Error: received nothing (errors so far: {0}).'.format(error))
    print("\033[0m" + "**************************************")
    print("**************************************")
    ser.close()
    sys.exit(-1)
  for b in bs:
    rb.append(b)
  n = n + read_packed_size
  pbr.update(read_packed_size)
pbr.close()

random.seed(S)
i = 0
print('read {0} bytes'.format(len(rb)))
for v in rb:
  check = random.randint(0,255)

  if i % 2 == 0:
    check = 0x55
  else:
    check = 0xAA

  if check != v:
    print("expected {0:02X} found {1:02X} at {2:02X}".format(check,v,i))
    error = error + 1
  i = i + 1

if error > 0:
  print("**************************************")
  print("**************************************")
  print("\033[91m" + 'Errors where found in {0} locations.'.format(error))
  print("\033[0m" + "**************************************")
  print("**************************************")
else:
  print("\033[92m" + "Success!" + "\033[0m")

ser.close()
