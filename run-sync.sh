#!/bin/bash

#
# This script orchestrates a SnapRAID sync operation by first creating
# Btrfs snapshots for a consistent state, then generating the appropriate
# snapraid.conf, and finally running the sync command.
#
# It's designed to be run as root, either manually or via a cron job.
#

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
SNAPRAID_CONFIG_PATH="/etc/snapraid.conf"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# --- Argument Validation ---
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run with root privileges. Please use sudo."
  exit 1
fi

echo "🚀 --- Starting SnapRAID Sync Process --- 🚀"

# 1. Create Btrfs snapshots for all ocean disks.
echo
echo "--- Step 1/3: Creating Btrfs Snapshots ---"
if ! "$SCRIPT_DIR/create-btrfs-snapshots.sh"; then
    echo "❌ ERROR: Snapshot creation failed. Aborting sync."
    exit 1
fi
echo "✅ Snapshots created successfully."


# 2. Run the SnapRAID sync command.
echo
echo "--- Step 2/3: Running SnapRAID Sync ---"
if ! snapraid sync; then
    echo "❌ ERROR: 'snapraid sync' command failed."
    exit 1
fi
echo "✅ SnapRAID sync completed successfully."

# 3. Cleanup old snapshots
echo 
echo "--- Step 3/3: Cleaning Up Old Snapshots ---"
if ! "$SCRIPT_DIR/remove-old-btrfs-snapshots.sh"; then
    echo "❌ ERROR: Cleanup of old snapshots failed."
    exit 1
fi

echo
echo "✨ --- SnapRAID Sync Process Finished --- ✨"
