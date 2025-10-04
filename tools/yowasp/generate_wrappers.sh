#!/usr/bin/env bash
set -euo pipefail

# This script produces wrappers for all yowasp executables
# listed in the wrappers.txt file.

# Paths
VENV_DIR="$HOME/.local/share/silice/.venv"
SETUP_SCRIPT="/usr/local/share/silice/setup-python-env.sh"
OUTDIR="$(cd "$(dirname "$0")" && pwd)"

# List of wrapper names, one per line
WRAPPERS_FILE="wrappers.txt"

# Checks
if [[ ! -f "$WRAPPERS_FILE" ]]; then
  echo "Error: $WRAPPERS_FILE not found." >&2
  exit 1
fi
if [[ ! -d "$OUTDIR" ]]; then
  echo "Error: output directory $OUTDIR does not exist." >&2
  exit 1
fi

# Generate wrappers
echo "Generating wrappers into: $OUTDIR"
while IFS= read -r tool_raw || [[ -n "$tool_raw" ]]; do
  # Trim
  tool="$(echo "$tool_raw" | tr -d '\r' | xargs)"
  # Skip
  [[ -z "$tool" || "$tool" =~ ^# ]] && continue
  # Wrapper name
  wrapper_path="$OUTDIR/$tool"
  # Output
  cat > "$wrapper_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
VENV_DIR="$VENV_DIR"
SETUP_SCRIPT="$SETUP_SCRIPT"
[ -x "\$SETUP_SCRIPT" ] && "\$SETUP_SCRIPT"
export PATH="\$VENV_DIR/bin:\$PATH"
export YOWASP=1
exec "\$VENV_DIR/bin/yowasp-$tool" "\$@"
EOF
  # Set as executable
  chmod +x "$wrapper_path"
  echo "Created: $wrapper_path"
done < "$WRAPPERS_FILE"

echo "All wrappers generated successfully."
