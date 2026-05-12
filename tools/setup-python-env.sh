#!/usr/bin/env bash

# This script is responsible for checking and setting up
# a local python environment for Silice.

set -euo pipefail

# Paths
VENV_DIR="$HOME/.local/share/silice/.venv"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REQ_FILE="$SCRIPT_DIR/requirements.txt"

# Detect MinGW
IS_MINGW=false
case "${MSYSTEM:-}" in
    MINGW32|MINGW64|MSYS|CLANG32|CLANG64|CLANGARM64|UCRT64)
        IS_MINGW=true
        ;;
esac
if [ "$IS_MINGW" = false ]; then
    case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*|CYGWIN*)
            IS_MINGW=true
            ;;
    esac
fi

# Create environment directory
mkdir -p "$(dirname "$VENV_DIR")"

# Create the python environment
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating and setting up venv at $VENV_DIR, this can take a few minutes"
    python3 -m venv "$VENV_DIR"
fi

PIP="$VENV_DIR/bin/pip"

if [ "$IS_MINGW" = true ]; then
    echo "MinGW environment detected — using apycula install workaround to avoid fastcrc and msgspec"

    TMP_REQ="$(mktemp /tmp/silice-req-XXXXXX.txt)"
    grep -v -iE '^(apycula|yowasp-nextpnr-himbaechel-gowin)' "$REQ_FILE" > "$TMP_REQ" || true
    "$PIP" install --quiet -r "$TMP_REQ"
    rm -f "$TMP_REQ"

    # Pure-Python replacements for the C extensions apycula would normally pull
    "$PIP" install --quiet numpy msgpack cattrs
    # Install the two packages without dependency resolution so pip never
    # attempts to build fastcrc or msgspec from source
    "$PIP" install --quiet --no-deps apycula
    "$PIP" install --quiet --no-deps yowasp-nextpnr-himbaechel-gowin
else
	# Normal install
    "$PIP" install --quiet -r "$REQ_FILE"
fi
