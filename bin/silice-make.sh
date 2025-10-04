#!/usr/bin/env bash
set -euo pipefail

# wrapper to invoke in the proper python environment

VENV_DIR="$HOME/.local/share/silice/.venv"
SETUP_SCRIPT="/usr/local/share/silice/setup-python-env.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Ensure the venv is initialized via your central setup script
"$SETUP_SCRIPT" "$VENV_DIR"

exec "$VENV_DIR/bin/python" "$SCRIPT_DIR/silice-make.py" "$@"
