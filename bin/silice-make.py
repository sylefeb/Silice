#!/usr/bin/env python3

import os
import sys
import json
import argparse
import platform
import sysconfig
from termcolor import colored

# command line
parser = argparse.ArgumentParser(description='silice-make is the Silice build tool')
parser.add_argument('-s','--source', help="Source file to build.")
parser.add_argument('-b','--board', help="Board to build for. Variant can be specified as board:variant")
parser.add_argument('-t','--tool', help="Tool used for building (edalize,shell).")
parser.add_argument('-p','--pins', help="Pins used in the design, comma separated, e.g. basic,vga")
parser.add_argument('-o','--outdir', help="Specify name of output directory.", default="BUILD")
parser.add_argument('-l','--list_boards', help="List all available target boards.", action="store_true")

args = parser.parse_args()

# check source file
if args.source:
    source_file = os.path.abspath(args.source)
    print("* Source file                : ",source_file,"   ",end='')
    if (os.path.exists(source_file)):
        print(colored("[ok]", 'green'))
    else:
        print(colored("[not found]", 'red'))
        sys.exit(-1)

# check directories
# - bin directory
make_dir = os.path.dirname(os.path.abspath(__file__))
print("* Silice bin directory       : ",make_dir)
os.environ["SILICE_DIR"] = make_dir
# - output directory
out_dir = os.path.realpath(args.outdir)
print("* Build output directory     : ",out_dir,end='')
try:
    os.mkdir(out_dir)
    print('  (created)')
except FileExistsError:
    print('  (exists)')
os.chdir(out_dir)
os.environ["BUILD_DIR"] = out_dir
# - frameworks directory
frameworks_dir = os.path.realpath(os.path.join(make_dir,"../frameworks/"))
print("* Silice frameworks directory: ",frameworks_dir,"\t\t\t",end='')
if (os.path.exists(frameworks_dir)):
    print(colored("[ok]", 'green'))
else:
    print(colored("[not found]", 'red'))
    sys.exit(-1)
os.environ["FRAMEWORKS_DIR"] = frameworks_dir

# get all boards definitions
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

# if asked, list boards and their options and exit
if args.list_boards:
    print("Available boards")
    for board in boards['boards']:
        board_path = os.path.realpath(os.path.join(frameworks_dir,"boards/" + board['name'] + "/board.json"))
        print("   - " + board['name'],end='')
        print("\t => description file ",end='')
        if (os.path.exists(board_path)):
            print(colored("[ok]", 'green'))
        else:
            print(colored("[not found]", 'yellow'))
        with open(board_path) as json_file:            
            board_def = json.load(json_file)
            # list all variants
            for variant in board_def['variants']:
                print('variant : ',colored(variant['name'], 'cyan'))
                print('pin sets:  ',end='')
                for pin_set in variant['pins']:
                    print(colored(pin_set['set'],'cyan'),' ',end='')
    sys.exit(0)

# check we have a board specified at this point
if not args.board:
    print(colored("no target board specified", 'red'))
    sys.exit(-1)

# split board/variant
target_board = args.board.split(":")[0]
target_variant_name = None
if len(args.board.split(":")) > 1:
    target_variant_name = args.board.split(":")[1]

# check we have a source file specified at this point
if not args.source:
    print(colored("no source file specified", 'red'))
    sys.exit(-1)

# inform user about what is happening
print(colored("<<=- compiling " + args.source + " for " + target_board + " -=>>", 'white', attrs=['bold']))

# check the board is indeed known
if not target_board in known_boards:
    print(colored("board " + target_board + " not available", 'red'))
    sys.exit(-1)

# load board definitions
board_path = os.path.realpath(os.path.join(frameworks_dir,"boards/" + target_board + "/"))
with open(board_path + "/board.json") as json_file:
    board_props = json.load(json_file)
os.environ["BOARD_DIR"] = board_path

# identify the board variant
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
# record pin sets
variant_pin_sets = {}
for pin_set in target_variant['pins']:
    variant_pin_sets[pin_set['set']] = pin_set

# check the selected tool exists (or selects default, first in json file)
if args.tool:
    target_builder = None
    for builder in target_variant['builders']:
        if builder['builder'] == args.tool:
            target_builder = builder
            break
    if target_builder == None:
        print(colored("builder '" + args.tool + "' not found", 'red'))
        sys.exit(-1)
else:
    target_builder = target_variant['builders'][0]
print('using build system    ',colored(target_builder['builder'],'cyan'))

# framework file
framework_file = os.path.realpath(os.path.join(board_path,target_variant['framework']))
os.environ["FRAMEWORK_FILE"] = framework_file

# ok, build!

if target_builder['builder'] == 'shell':

    # ==== building with a custom script

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
    # prepare additional defines
    defines = ""
    if args.pins:
        for pin_set in args.pins.split(','):
            if not pin_set in variant_pin_sets:
                print(color("pin set " + pin_set + " not defined in board variant",'red'))
            else:
                if 'define' in variant_pin_sets[pin_set]:
                    defines = defines + " -D " + variant_pin_sets[pin_set]['define']
    # execute
    command = script + " " + source_file
    print('launching command     ', colored(command,'cyan'))
    bash = "env bash"
    os.system(bash + " " + command + " " + defines)

elif target_builder['builder'] == 'edalize':

    # ==== building with Edalize

    my_env = os.environ
    my_env["PATH"] = make_dir + os.pathsep + my_env["PATH"]

    from edalize import get_edatool
    import subprocess

    tool   = target_builder['tool']
    constr = target_builder['constraints'][0]

    # prepare additional defines
    defines = {}
    if args.pins:
        for pin_set in args.pins.split(','):
            if not pin_set in variant_pin_sets:
                print(color("pin set " + pin_set + " not defined in board variant",'red'))
            else:
                if 'define' in variant_pin_sets[pin_set]:
                    defines[pin_set] = variant_pin_sets[pin_set]['define']
    # prepare edam structure                    
    edam = {'name' : 'build',
            'files': [{'name': 'build.v', 'file_type': 'verilogSource'},
                        {'name': board_path + "/" + constr['name'],
                        'file_type': constr['file_type']}
                        ],
            'tool_options': {tool: target_builder["tool_options"][0]},
            'toplevel' : 'top',
            }
    cmd = ["silice", "-f", framework_file, source_file, "-o", "build.v"]
    for d in defines:
        cmd.append("-D")
        cmd.append(defines[d])

    try:
        subprocess.check_call(cmd, cwd=out_dir, env=my_env, stdin=subprocess.PIPE)
    except FileNotFoundError as e:
        raise RuntimeError("Unable to run script '{}': {}".format(cmd, str(e)))
    except subprocess.CalledProcessError as e:
        raise RuntimeError("script '{}' exited with error code {}".format(
            cmd, e.returncode))

    backend = get_edatool(tool)(edam=edam, work_root=out_dir)
    backend.configure()
    backend.build()

    print(colored('programming device ... ','white', attrs=['bold']))
    for program in target_builder['program']:
        try:
            prog = program['cmd']
            args = program['args']            
            cmd = [prog] + args.split(' ')
            try:
                subprocess.check_call(cmd, cwd=out_dir, env=my_env, stdin=subprocess.PIPE)
            except FileNotFoundError as e:
                print(colored('<<error>>','red'))
                raise RuntimeError("Unable to run script '{}': {}".format(cmd, str(e)))
            except subprocess.CalledProcessError as e:
                print(colored('<<error>>','red'))
                raise RuntimeError("script '{}' exited with error code {}".format(
                    cmd, e.returncode))
        except KeyError as e:
            print(colored('<<error in board.json>>','red'))
            raise RuntimeError("missing key {}".format(str(e)))
    print(colored('done.','green'))
            
else:
    print(colored("builder '" + target_variant_name + "' not implemented", 'red'))
