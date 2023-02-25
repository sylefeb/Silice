import re
import argparse

parser = argparse.ArgumentParser(description='tool to produce exercises from full source')
parser.add_argument('-i','--input', help="Input source file.")
parser.add_argument('-s','--solutions', help="Comma separated list of solutions.")

args = parser.parse_args()

if args.solutions:
  solutions = args.solutions.split(',')
else:
  solutions = []

f = open(args.input, 'r')
lines = f.readlines()

prev_empty = False

stack = []
stack.append([True,0])

for i,line in enumerate(lines):
  skip = 0
  if re.match("^\s*\$\$if\s+Solution_",line):
    if any(q in line for q in solutions):
      stack.append([stack[-1][0],1])
    else:
      stack.append([False,1])
    skip = 1
  elif re.match("^\s*\$\$if\s+not\s+Solution_",line):
    if any(q in line for q in solutions):
      stack.append([False,1])
    else:
      stack.append([stack[-1][0],1])
    skip = 1
  elif re.match("^\s*\$\$if",line):
    stack.append([stack[-1][0],0])
    skip = 0
  elif re.match("^\s*\$\$for",line):
    stack.append([stack[-1][0],0])
    skip = 0
  elif re.match("^\s*\$\$else",line):
    state = stack[-1][0]
    skip  = stack[-1][1]
    stack.pop()
    stack.append([stack[-1][0] and (not state),skip])
  elif re.match("^\s*\$\$end",line):
    skip  = stack[-1][1]
    stack.pop()
  if stack[-1][0] and skip == 0:
    str = line.rstrip()
    if len(str) > 0:
      print(str)
      prev_empty = False
    elif not prev_empty:
      print(str)
      prev_empty = True

f.close()
