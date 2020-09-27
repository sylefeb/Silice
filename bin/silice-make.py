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

make_dir = os.path.dirname(os.path.abspath(__file__))
print("* Silice bin directory       : ",make_dir)
os.environ["SILICE_DIR"] = make_dir

out_dir = os.path.realpath(args.outdir)
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
os.environ["FRAMEWORKS_DIR"] = frameworks_dir

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
    sys.exit(0)

if not args.board:
    print(colored("no target board specified", 'red'))
    sys.exit(-1)

target_board = args.board.split(":")[0]
target_variant_name = None
if len(args.board.split(":")) > 1:
    target_variant_name = args.board.split(":")[1]

if not args.source:
    print(colored("no source file specified", 'red'))
    sys.exit(-1)

print(colored("<<=- compiling " + args.source + " for " + target_board + " -=>>", 'white', attrs=['bold']))

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

if args.tool:
    target_builder = None
    for builder in board_props['builders']:
        if builder['builder'] == args.tool:
            target_builder = builder
            break
    if target_builder == None:
        print(colored("builder '" + args.tool + "' not found", 'red'))
        sys.exit(-1)
else:
    target_builder = board_props['builders'][0]

print('using build system    ',colored(target_builder['builder'],'cyan'))

framework_file = os.path.realpath(os.path.join(board_path,target_variant['framework']))
os.environ["FRAMEWORK_FILE"] = framework_file

if target_builder['builder'] == 'shell':

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
    bash = "C:/msys64/usr/bin/bash.exe"
    if not os.path.exists(script):
        print(colored("MSYS2 bash not found", 'red'))
        sys.exit()            
    if platform.system() == "Windows":
        ## TODO better way to detect where mingw bash is?
        ##      unfortunately we cannot use /usr/bin/path as os.system spawns a Windows env
        os.system("C:/msys64/usr/bin/bash.exe " + command)
    else:
        os.system("bash " + command)

elif target_builder['builder'] == 'edalize':

    my_env = os.environ
    my_env["PATH"] = make_dir + os.pathsep + my_env["PATH"]

    from edalize import get_edatool
    from shlex import join
    import subprocess

    tool   = target_builder['tool']
    constr = target_builder['constraints'][0]

    edam = {'name' : 'build',
            'files': [{'name': 'build.v', 'file_type': 'verilogSource'},
                        {'name': board_path + "/" + constr['name'],
                        'file_type': constr['file_type']}
                        ],
            'tool_options': {tool: target_builder["tool_options"][0]},
            'toplevel' : 'top'
            }

    cmd = ["silice", "-f", framework_file, source_file, "-o", "build.v"]

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

    try:
        program = board_props['program'][0]
        prog = program['cmd']
        bitstream = "build." + program['bit_format']
        try:
            args = program['args']
            cmd = [prog, args, bitstream]
        except KeyError as e:
            cmd = [prog, bitstream]

        try:
            subprocess.check_call(cmd, cwd=out_dir, env=my_env, stdin=subprocess.PIPE)
        except FileNotFoundError as e:
            raise RuntimeError("Unable to run script '{}': {}".format(cmd, str(e)))
        except subprocess.CalledProcessError as e:
            raise RuntimeError("script '{}' exited with error code {}".format(
                cmd, e.returncode))
    except KeyError as e:
        pass
else:
    print(colored("builder '" + target_variant_name + "' not implemented", 'red'))
