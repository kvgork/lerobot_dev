#!/usr/bin/env bash
# lero_setup_env.sh — interactive setup for LeRobot hardware environment variables
# Writes LERO_FOLLOWER_PORT, LERO_LEADER_PORT, and LERO_CAM_SERIAL to ~/.bashrc
# Run once after setting up hardware. Re-run to update values.

set -euo pipefail

BASHRC="$HOME/.bashrc"
MARKER_START="# --- LeRobot hardware env vars (managed by lero_setup_env.sh) ---"
MARKER_END="# --- end LeRobot hardware env vars ---"

echo ""
echo "=== LeRobot Hardware Environment Setup ==="
echo ""
echo "Tip: run 'lero-find-port' to discover serial ports,"
echo "     run 'lero-find-cameras realsense' to find the camera serial."
echo ""

# Prompt with current value shown as default
read_with_default() {
    local prompt="$1"
    local default="$2"
    local value
    read -rp "${prompt} [${default}]: " value
    echo "${value:-$default}"
}

# Read current values from bashrc if they exist (for showing as defaults)
current_follower=$(grep -oP "(?<=LERO_FOLLOWER_PORT=)[^\s]+" "$BASHRC" 2>/dev/null | tail -1 || true)
current_leader=$(grep -oP "(?<=LERO_LEADER_PORT=)[^\s]+" "$BASHRC" 2>/dev/null | tail -1 || true)
current_serial=$(grep -oP "(?<=LERO_CAM_SERIAL=)[^\s]+" "$BASHRC" 2>/dev/null | tail -1 || true)

FOLLOWER_PORT=$(read_with_default "Follower arm serial port" "${current_follower:-/dev/ttyACM0}")
LEADER_PORT=$(read_with_default "Leader arm serial port"   "${current_leader:-/dev/ttyACM1}")
CAM_SERIAL=$(read_with_default  "RealSense D435 serial number (leave empty if no camera)" "${current_serial:-}")

echo ""
echo "Writing to $BASHRC:"
echo "  LERO_FOLLOWER_PORT=$FOLLOWER_PORT"
echo "  LERO_LEADER_PORT=$LEADER_PORT"
echo "  LERO_CAM_SERIAL=$CAM_SERIAL"
echo ""

# Remove old block if it exists
if grep -qF "$MARKER_START" "$BASHRC"; then
    # Use python to remove the block reliably (avoids sed multiline portability issues)
    python3 - "$BASHRC" "$MARKER_START" "$MARKER_END" <<'EOF'
import sys
path, start, end = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    lines = f.readlines()
out, skip = [], False
for line in lines:
    if line.strip() == start:
        skip = True
    if not skip:
        out.append(line)
    if skip and line.strip() == end:
        skip = False
with open(path, 'w') as f:
    f.writelines(out)
EOF
fi

# Append new block
cat >> "$BASHRC" <<EOF

${MARKER_START}
export LERO_FOLLOWER_PORT=${FOLLOWER_PORT}
export LERO_LEADER_PORT=${LEADER_PORT}
export LERO_CAM_SERIAL=${CAM_SERIAL}
${MARKER_END}
EOF

echo "Done. Run 'source ~/.bashrc' (or alias: src_b) to apply."
