#!/usr/bin/env bash

# This script is responsible for checking and setting up
# a local python environment for Silice.

set -euo pipefail

# Paths
VENV_DIR="$HOME/.local/share/silice/.venv"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REQ_FILE="$SCRIPT_DIR/requirements.txt"
# Create environment director
mkdir -p "$(dirname "$VENV_DIR")"
# Create the python environment
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating venv at $VENV_DIR"
    python3 -m venv "$VENV_DIR"
fi
# Install
"$VENV_DIR/bin/pip" install --quiet -r "$REQ_FILE"
