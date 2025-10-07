#!/bin/bash

#
# This script finds and removes old btrfs snapshots created by
# create-btrfs-snapshots.sh, keeping a specified number of recent snapshots.
#

# Default number of snapshots to keep
KEEP_COUNT=10

# Parse command-line arguments
if [[ "$1" == "--keep-count" ]]; then
    if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
        KEEP_COUNT=$2
        shift 2
    else
        echo "Error: --keep-count requires a numeric argument."
        exit 1
    fi
fi

SNAPRAID_DIR=".snapraid"
DATA_SNAPSHOT_NAME="btrfs_checkpoint"
SNAPSHOT_PATTERN_BASE="${DATA_SNAPSHOT_NAME}_old"
LABEL_PATTERN="^ocean[dp][0-9][0-9]$"
FSTYPE="btrfs"

echo "🧹 --- Cleaning up old SnapRAID Btrfs Snapshots ---"
echo "    Keeping the ${KEEP_COUNT} most recent snapshots."

# Find all relevant mount points and labels using a single lsblk call
DISK_INFO=$(lsblk -n -o LABEL,FSTYPE,MOUNTPOINT | awk -v pattern="$LABEL_PATTERN" -v fstype="$FSTYPE" '
    $1 ~ pattern && $2 == fstype && $3 != "" { print $1 " " $3 }
' | sort)

if [ -z "$DISK_INFO" ]; then
    echo "⚠️  No ocean disks found. Exiting."
    exit 1
fi

echo "$DISK_INFO" | while read -r LABEL mp; do
    echo "🧭 Processing disk ${LABEL} at mount point: ${mp}"

    SNAPSHOT_DIR="${mp}/${SNAPRAID_DIR}"

    if [ ! -d "${SNAPSHOT_DIR}" ]; then
        echo "  ⏭️  Snapshot directory ${SNAPSHOT_DIR} not found. Skipping."
        continue
    fi

    # Find all old snapshots for the current mount point, sorted oldest to newest
    OLD_SNAPSHOTS=()
    while IFS= read -r line; do
        OLD_SNAPSHOTS+=("$line")
    done < <(find "${SNAPSHOT_DIR}" -maxdepth 1 -type d -name "${SNAPSHOT_PATTERN_BASE}*" | sort)

    NUM_SNAPSHOTS=${#OLD_SNAPSHOTS[@]}
    echo "  🔎 Found ${NUM_SNAPSHOTS} old snapshot(s)."

    if [ ${NUM_SNAPSHOTS} -gt ${KEEP_COUNT} ]; then
        NUM_TO_DELETE=$((NUM_SNAPSHOTS - KEEP_COUNT))
        echo "  🗑️  Will delete ${NUM_TO_DELETE} oldest snapshot(s)."

        for (( i=0; i<${NUM_TO_DELETE}; i++ )); do
            SNAPSHOT_TO_DELETE="${OLD_SNAPSHOTS[$i]}"
            echo "    - Deleting ${SNAPSHOT_TO_DELETE}..."
            sudo btrfs subvolume delete "${SNAPSHOT_TO_DELETE}"
            if [ $? -ne 0 ]; then
                echo "      ❌ ERROR: Failed to delete snapshot. Please check permissions or if it's a valid subvolume."
            else
                echo "      ✅ Snapshot deleted successfully."
            fi
        done
    else
        echo "  👍 No snapshots to delete."
    fi
done

echo "✨ --- Snapshot cleanup process complete ---"
