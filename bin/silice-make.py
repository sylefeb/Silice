import os
import sys
import json
import getopt
import platform
import sysconfig
from termcolor import colored

# command line
source = None
target = None
outdir = None
if len(sys.argv) < 2:
    print("no source file no command line")
else:
    source = sys.argv[1]
    try:
        opts, args = getopt.getopt(sys.argv[2:],"hb:o:",["help","source=","board=","outdir="])
    except getopt.GetoptError:
        print("no command line arguments")
    for opt, arg in opts:
        if opt == '-h' or opt == '--help':
            print("Usage: silice-make.py -s <source.ice> -b <board>")
            sys.exit()
        elif opt == '-s' or opt == '--source':
            source = arg
        elif opt == '-b' or opt == '--board':
            target = arg
        elif opt == '-o' or opt == '--outdir':
            outdir = arg

list_boards = False
if source == None or target == None:
    list_boards = True

if outdir == None:
    outdir = "./BUILD/"

# check source file
source_file = os.path.abspath(source)
print("* Source file                : ",source_file,"   ",end='')
if (os.path.exists(source_file)):
    print(colored("[ok]", 'green'))
else:
    print(colored("[not found]", 'red'))
    sys.exit(-1)

# check directories

make_dir = os.path.dirname(os.path.abspath(__file__))
print("* Silice bin directory       : ",make_dir)
os.environ["SILICE_DIR"] = make_dir

out_dir = os.path.realpath(outdir)
print("* Build output directory     : ",out_dir,end='')
try:
    os.mkdir(out_dir)
    print('  (created)')
except FileExistsError:
    print('  (exists)')
os.chdir(out_dir)
os.environ["BUILD_DIR"] = out_dir

frameworks_dir = os.path.realpath(os.path.join(make_dir,"../frameworks/"))
print("* Silice frameworks directory: ",frameworks_dir,"\t\t\t",end='')
if (os.path.exists(frameworks_dir)):
    print(colored("[ok]", 'green'))
else:
    print(colored("[not found]", 'red'))
    sys.exit(-1)

# list all boards

boards_path = os.path.realpath(os.path.join(frameworks_dir,"boards/boards.json"))
print("* boards description file    : ",boards_path,"\t",end='')
if (os.path.exists(boards_path)):
    print(colored("[ok]", 'green'))
else:
    print(colored("[not found]", 'red'))
    sys.exit(-1)

known_boards = {}
with open(boards_path) as json_file:
    boards = json.load(json_file)
    for board in boards['boards']:
        board_path = os.path.realpath(os.path.join(frameworks_dir,"boards/" + board['name'] + "/board.json"))
        if (os.path.exists(board_path)):
            known_boards[board['name']] = board_path

if list_boards:
    print("Available boards")
    for board in boards['boards']:
        board_path = os.path.realpath(os.path.join(frameworks_dir,"boards/" + board['name'] + "/board.json"))
        print("   - " + board['name'],end='')
        print("\t => description file ",end='')
        if (os.path.exists(board_path)):
            print(colored("[ok]", 'green'))
        else:
            print(colored("[not found]", 'yellow'))
    sys.exit(0)

target_board   = target.split(":")[0]
target_variant_name = None
if len(target.split(":")) > 1:
    target_variant_name = target.split(":")[1]

print(colored("<<=- compiling " + source + " for " + target_board + " -=>>", 'white', attrs=['bold']))

if not target_board in known_boards:
    print(colored("board " + target_board + " not available", 'red'))
    sys.exit(-1)

board_path = os.path.realpath(os.path.join(frameworks_dir,"boards/" + target_board + "/"))
with open(board_path + "/board.json") as json_file:
    board_props = json.load(json_file)
os.environ["BOARD_DIR"] = board_path

target_variant = None
if target_variant_name == None:
    target_variant = board_props['variants'][0]
    print('using default variant ',colored(target_variant['name'],'cyan'))
else:
    for variant in board_props['variants']:
        if variant['name'] == target_variant_name:
            target_variant = variant
            break
if target_variant == None:
    print(colored("variant " + target_variant_name + " not found", 'red'))
else:
    print('using variant         ',colored(target_variant['name'],'cyan'))

target_builder = None # in the future we may allow to choose between different build systems
if target_builder == None:
    target_builder = board_props['builders'][0]
    print('using build system    ',colored(target_builder['system'],'cyan'))

os.environ["FRAMEWORK_FILE"] = os.path.realpath(os.path.join(board_path,target_variant['framework']))

if target_builder['system'] == 'shell':
    # system checks
    if platform.system() == "Windows":
        if not sysconfig.get_platform() == "mingw":
            print(colored("to build from scripts please run MinGW python from a shell",'red'))
            sys.exit(-1)
    # script check
    script = os.path.join(board_path,target_builder['command'])
    if not os.path.exists(script):
        print(colored("script " + script + " not found", 'red'))
        sys.exit()
    # execute
    command = script + " " + source_file
    print('launching command     ', colored(command,'cyan'))
    if platform.system() == "Windows":
        bash = "C:/msys64/usr/bin/bash.exe"
        if not os.path.exists(script):
            print(colored("MSYS2 bash not found", 'red'))
            sys.exit()            
        os.system("C:/msys64/usr/bin/bash.exe " + command)
    else:
        os.system(command)
