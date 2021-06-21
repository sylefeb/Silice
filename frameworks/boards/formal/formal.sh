#!/usr/bin/env bash

case "$(uname -s)" in
MINGW*|CYGWIN*) 
SILICE_DIR=`cygpath $SILICE_DIR`
BUILD_DIR=`cygpath $BUILD_DIR`
FRAMEWORKS_DIR=`cygpath $FRAMEWORKS_DIR`
FRAMEWORK_FILE=`cygpath $FRAMEWORK_FILE`
BOARD_DIR=`cygpath $BOARD_DIR`
;;
*)
esac

echo "build script: SILICE_DIR     = $SILICE_DIR"
echo "build script: BUILD_DIR      = $BUILD_DIR"
echo "build script: BOARD_DIR      = $BOARD_DIR"
echo "build script: FRAMEWORKS_DIR = $FRAMEWORKS_DIR"
echo "build script: FRAMEWORK_FILE = $FRAMEWORK_FILE"

export PATH=$PATH:$SILICE_DIR:$SILICE_DIR/../tools/fpga-binutils/mingw64/bin/
case "$(uname -s)" in
MINGW*)
export PYTHONHOME=/mingw64/bin
export PYTHONPATH=/mingw64/lib/python3.8/
export QT_QPA_PLATFORM_PLUGIN_PATH=/mingw64/share/qt5/plugins
;;
*)
esac

cd $BUILD_DIR

rm build*
rm -r formal* *.smtc  # formal.log formal.sby *.smtc formal_*/

if ! silice --frameworks_dir $FRAMEWORKS_DIR -f '' -o build.v $1 "${@:2}"; then
  exit 1
fi


if ! [ -f "build.v.alg.log" ]; then
    >&2 echo "File '$PWD/build.v.alg.log' not found. Did the compiler generate one?"
    exit 1
fi

LOG_LINES="$(cat build.v.alg.log)"
LOG_LINES="$(sed -e '/./,$!d' -e :a -e '/^\n*$/{$d;N;ba' -e '}' <<< "$LOG_LINES")"
# adaptated from: https://unix.stackexchange.com/a/552195
# Remove empty lines at the beginning and end of the string
echo 'initial
assume (= [reset] true)

state 1:*
assume (= [reset] false)

state 2:*
assume (= [in_run] true)

final
assume (= [in_run] false)' > constraints.smtc

touch formal.sby

COVER="false"
while [ "$COVER" = "false" ] && IFS= read -r LOG; do
  COVER=$(awk '
BEGIN {
  found = 0
}
$1 ~ /formal(.*?)\$$/ && $7 != "" {
  split($7, modes, /,/)

  for (m in modes) {
    if ("cover" == modes[m]) {
      found = 1
      exit
    }
  }
}
END {
  print (found ? "true" : "false")
}' <<< "$LOG")
done <<< "$LOG_LINES"

I=0
echo "[tasks]" > formal.sby
while IFS= read -r LOG; do
    awk '
$2 ~ /^formal(.*?)\$$/ && $8 != "" {
  split($8, modes, /,/)

  for (mode in modes) {
    printf "%s-%s task-%d-%d\n", $4, modes[mode], $1, mode
  }
}' <<< "$I $LOG" >> formal.sby
    I=$((I + 1))
done <<< "$LOG_LINES"

I=0
echo "
[options]
wait on" >> formal.sby
while IFS= read -r LOG; do
    awk -v SMTC="$SMTC" '
function to_mode(mode) {
  switch (mode) {
    case "tind": return "prove"
    default: return mode
  }
}

$2 ~ /^formal(.*?)\$$/ && $8 != "" {
   split($8, modes, /,/)
   for (mode in modes) {
     printf "task-%d-%d:\n  depth %d\n  timeout %d\n  mode %s\n", $1, mode, $6, $7, to_mode(modes[mode])
     switch(modes[mode]) {
       case "tind":
       case "bmc":
         print "  smtc constraints.smtc"
         break
       case "cover":
         print "  append 10"
         break
       default:
         break
     }
   }
}' <<< "$I $LOG" >> formal.sby
    I=$((I + 1))
done <<< "$LOG_LINES"

I=0
echo '--

[engines]' >> formal.sby
while IFS= read -r LOG; do
  awk '
$2 ~ /^formal(.*?)\$$/ && $8 != "" {
  split($8, modes, /,/)

  for (mode in modes) {
    printf "task-%d-%d: smtbmc --stbv --progress yices\n", $1, mode
  }
}
' <<< "$I $LOG" >> formal.sby
  I=$((I + 1))
done <<< "$LOG_LINES"

I=0
echo "
[script]
read_verilog -formal build.v
" >> formal.sby
while IFS= read -r LOG; do
    awk '
$2 ~ /^formal(.*?)\$$/ && $8 != "" {
  split($8, modes, /,/)

  for (mode in modes) {
    print "task-" $1 "-" mode ": prep -top M_" $4 "_" $2
  }
}' <<< "$I $LOG" >> formal.sby
    I=$((I + 1))
done <<< "$LOG_LINES"

echo "
[files]
build.v" >> formal.sby
for FILE in $(find . -maxdepth 1 -type f -name '*.smtc' -print | cut -c3-); do
    echo "$FILE" >> formal.sby
done

MAX_LENGTH=$(awk '{ n = length($3); if (n > len) len = n } END { print len + 9 }' <<< "$LOG_LINES")

if ! command -v sby &>/dev/null; then
    >&2 echo "##### Symbiyosys (sby) not found! #####"
    >&2 echo ""
    >&2 echo "Make sure it is installed and in your \$PATH."
    >&2 echo "For more information about installing, see <https://symbiyosys.readthedocs.io/en/latest/install.html>."
    exit 1
fi

echo "---< Running Symbiyosys >---"

AWKSCRIPT='
function to_result(r) {
  switch(r) {
    case "FAIL":
    case "UNKNOWN": return "\033[31mfailed\033[0m"
    case "PASS": return "\033[32mpassed\033[0m"
  }
}

BEGIN {
  TOLEFT = "\033[0G\033[0K\033[0m"
}
$0 ~ /Reached TIMEOUT/ {
  gsub(/formal_/, "", $3)
  print TOLEFT "* " sprintf("%" LEN "-s", $3) "\033[33mtimeout\033[0m"
}
match($0, /DONE \((UNKNOWN|PASS|FAIL),/, gr) {
  gsub(/formal_/, "", $3)

  print TOLEFT "* " sprintf("%" LEN "-s", $3) to_result(gr[1])
}
$0 ~ /(build\.v:[0-9]+: ERROR: .*)$/ {
  gsub(/formal_/, "", $3)
  print TOLEFT "* " sprintf("%" LEN "-s", $3) "\033[31;1mfatal\033[0m"
}
$0 ~ /(SMT Solver '"'"'.*?'"'"' not found in path.)$/ {
  gsub(/formal_/, "", $3)
  print TOLEFT "* " sprintf("%" LEN "-s", $3) "\033[31;1mfatal\033[0m"
  next
}
$0 ~ /(yosys-abc: command not found)$/ {
  gsub(/formal_/, "", $3)
  print TOLEFT "* " sprintf("%" LEN "-s", $3) "\033[31;1mfatal\033[0m"
  next
}
match($0, /(Verification of invariant .*)$/, gr) {
  gsub(/formal_/, "", $3)
  printf TOLEFT "* " sprintf("%" LEN "-s", $3) "\033[34m" gr[1] "\033[0m"
}
match($0, /(Invariant .*)$/, gr) {
  gsub(/formal_/, "", $3)
  printf TOLEFT "* " sprintf("%" LEN "-s", $3) "\033[34m" gr[1] "\033[0m"
}
match($0, /(Property proved\. .*)$/, gr) {
  gsub(/formal_/, "", $3)
  printf TOLEFT "* " sprintf("%" LEN "-s", $3) "\033[34m" gr[1] "\033[0m"
}
match($0, /(Counter-example .*)$/, gr) {
  gsub(/formal_/, "", $3)
  printf TOLEFT "* " sprintf("%" LEN "-s", $3) "\033[34m" gr[1] "\033[0m"
}
$5 == "##" {
  gsub(/formal_/, "", $3)
  printf "%s", TOLEFT "* " sprintf("%" LEN "-s", $3) "\033[34m"
  for (i = 7; i <= NF; i++)
    printf "%s", $i " "
}
{ printf "" }
'

sby -f formal.sby | tee logfile.txt | awk -v LEN=$MAX_LENGTH "$AWKSCRIPT"
# Because we're piping, we need to check if the status of the pipe is not ok.
if [ "${PIPESTATUS[0]}" != "0" -o "$COVER" = "true" ]; then
    echo ""
    echo "---<       Results      >---"
    AWKSCRIPT='
function try_read_silice_position(line) {
  build_v = "build.v"

  NR_ = 0
  file = "<original file not found>"
  while ((getline build_v_line < build_v) > 0) {
    if (++NR_ == line && match(build_v_line, /\/\/%(.*)$/, gr_)) {
      file = gr_[1]
      break
    }
  }
  close(build_v)

  return file
}

match($0, /((BMC|Temporal induction) failed!)/, gr) {
  gsub(/formal_/, "", $3)

  step = ""
  if (match($4, /\.(basecase|induction)/, gr_)) {
    step = gr_[1]
  }

  print "* " sprintf("%" LEN "-s", $3) "\033[31m" (step == "" ? "" : "\033[4m" step ":" "\033[0m\033[31m ") gr[1] "\033[0m"
}
match($0, /(Assert failed in ).*?: build\.v:(.*)$/, gr) {
  gsub(/formal_/, "", $3)
  gsub(/[0-9]+\.[0-9]+-/, "", gr[2])
  gsub(/\.[0-9]+/, "", gr[2])

  gr[2] = try_read_silice_position(gr[2])

  print sprintf("%" (LEN + 2) "-s", "") "\033[31m" gr[1] gr[2] "\033[0m"
}
match($0, /(Unreached cover statement at )build\.v:([0-9\-\.]+)\.$/, gr) {
  gsub(/formal_/, "", $3)
  gsub(/[0-9]+\.[0-9]+-/, "", gr[2])
  gsub(/\.[0-9]+/, "", gr[2])

  gr[2] = try_read_silice_position(gr[2])

  print "* " sprintf("%" LEN "-s", $3) "\033[31m" gr[1] gr[2] ".\033[0m"
}
match($0, /(Reached cover statement at )build\.v:([0-9\-\.]+)( in step [0-9]+\.)$/, gr) {
  build_v = "build.v"

  gsub(/formal_/, "", $3)
  gsub(/[0-9]+\.[0-9]+-/, "", gr[2])
  gsub(/\.[0-9]+/, "", gr[2])

  gr[2] = try_read_silice_position(gr[2])

  print "* " sprintf("%" LEN "-s", $3) "\033[32m" gr[1] gr[2] gr[3] "\033[0m"
}
match($0, /(Writing trace to VCD file: )(.*)$/, gr) {
  gsub(/(\[|\])/, "", $3)
  gr[2] = PWD "/" $3 "/" gr[2]

  print "  " sprintf("%" LEN "-s", "") ($3 ~ /-cover$/ ? "\033[32m" : "\033[31m") gr[1] gr[2] "\033[0m"
}
match($0, /(Assumptions are unsatisfiable!)$/, gr) {
  gsub(/formal_/, "", $3)

  print "* " sprintf("%" LEN "-s", $3) "\033[31m" gr[1] "\033[0m"
}
match($0, /Reached TIMEOUT \((.*?)\)\./, gr) {
  gsub(/formal_/, "", $3)

  print "* " sprintf("%" LEN "-s", $3) "\033[33mTimed out after " gr[1] "\033[0m"
}
match($0, /(build\.v:[0-9]+: ERROR: .*)$/, gr) {
  gsub(/formal_/, "", $3)

  print "* " sprintf("%" LEN "-s", $3) "\033[31;1m" gr[1] "\033[0m"
}
match($0, /(SMT Solver '"'"'.*?'"'"' not found in path.)$/, gr) {
  gsub(/formal_/, "", $3)

  print TOLEFT "* " sprintf("%" LEN "-s", $3) "\033[31;1m" gr[1] "\033[0m"
}
match($0, /(yosys-abc: command not found)$/, gr) {
  gsub(/formal_/, "", $3)
  print TOLEFT "* " sprintf("%" LEN "-s", $3) "\033[31;1m" gr[1] "\033[0m"
  next
}'
    awk -v LEN=$MAX_LENGTH -v PWD="$PWD" "$AWKSCRIPT" < logfile.txt
    exit 1
fi