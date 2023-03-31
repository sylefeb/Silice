#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# MIT license see LICENSE_MIT in project root
# -----------------------------------------------------------------------------
#
# Outputs a colored version of the source file where the color of each line
# corresponds to a design state: all lines with the same color are active
# during the same cycle. Colors randomly changed at every run, it is recommanded
# to run a few times to clear any doubts due to similar colors.
#
# -----------------------------------------------------------------------------

import sys
import hashlib
import random
import os

if len(sys.argv) < 3:
    print("Usage: report-cycles.py <target> <source.si>")
    sys.exit(1)

target = sys.argv[1]
source = sys.argv[2]
unique_pairs = {}
default_color = f'\u001b[38;5;15m' # escape code for bold white
last_id = None
rnd = random.randint(0,255)

print("\n")

# Read FSM report for the source file, from the build directory
with open("./BUILD_" + target + "/" + os.path.basename(source) + ".fsm.log", 'r') as f:
    for line in f:
        words = line.strip().split()
        pair = tuple(words[:2])
        id = int(words[2])
        numbers = list(map(int, words[3:]))
        unique_pairs.setdefault(pair, {}).setdefault(id, set()).update(numbers)

# Read the source line by line and color lines based on FSM report
with open(source, 'r') as f:
    line_num = 0
    for line in f:
        line_num += 1
        id_found = False
        for pair, data in unique_pairs.items():
            for id, numbers in data.items():
                if line_num in numbers:
                    color_id = int(hashlib.sha256((pair[1]+str(id)+str(rnd)).encode('utf-8')).hexdigest(), 16)
                    # escape code for highlighted color
                    color = f'\u001b[38;5;{str(100+(color_id%131))}m'
                    # print line with highlighted color and no newline
                    print(f'{color}{line}{default_color}', end='')
                    last_id = id
                    id_found = True
                    break
            if id_found:
                break
        if not id_found:
            # no information for this line
            print(f'{default_color}{line}{default_color}', end='')  # print line with default color 
        else:
            last_id = id  # track last_id
# done
print("\033[0m\n")
