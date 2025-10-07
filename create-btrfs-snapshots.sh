#!/bin/bash

#
# This script finds all ocean[dp]## btrfs mounts and creates a
# consistent, read-only snapshot named '_snapraid_sync' on each one.
# This should be run immediately before a 'snapraid sync' command.
#

SNAPRAID_DIR=".snapraid"
DATA_SNAPSHOT_NAME=".snapraid/btrfs_checkpoint"
LABEL_PATTERN="^ocean[dp][0-9][0-9]$"
FSTYPE="btrfs"
TIMESTAMP=$(date +%m-%d-%H-%M-%S)

echo "📸 --- Preparing SnapRAID Btrfs Snapshots ---"

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

    # Ensure the .snapraid directory exists
    if [ ! -d "${mp}/${SNAPRAID_DIR}" ]; then
    echo "  📁 Creating directory ${mp}/${SNAPRAID_DIR}..."
        mkdir -p "${mp}/${SNAPRAID_DIR}"
        if [ $? -ne 0 ]; then
            echo "  ❌ ERROR: Failed to create directory. Please check permissions."
            continue
        fi
    fi

    if [[ $LABEL =~ .*d[0-9]{2}$ ]]; then
        # Data disk
        SNAPSHOT_PATH="${mp}/${DATA_SNAPSHOT_NAME}"
        OLD_SNAPSHOT_PATH="${SNAPSHOT_PATH}_old${TIMESTAMP}"

        if [ -d "${SNAPSHOT_PATH}" ]; then
            echo "  📦 Renaming current snapshot to ${OLD_SNAPSHOT_PATH}..."
            mv "${SNAPSHOT_PATH}" "${OLD_SNAPSHOT_PATH}"
            if [ $? -ne 0 ]; then
                echo "  ❌ ERROR: Failed to rename current snapshot. Please check permissions."
                continue
            fi
        fi

        echo "  🆕 Creating new read/write snapshot at ${SNAPSHOT_PATH}..."
        sudo btrfs subvolume snapshot "${mp}" "${SNAPSHOT_PATH}"
        if [ $? -ne 0 ]; then
            echo "  ❌ ERROR: Failed to create new snapshot."
        else
            echo "  ✅ Snapshot created successfully."
        fi
    elif [[ $LABEL =~ .*p[0-9]{2}$ ]]; then
        SNAPSHOT_PATH="${mp}/${DATA_SNAPSHOT_NAME}_old${TIMESTAMP}" # Snapshot of the parity at that timestamp
        echo "  🆕 Creating new read/write snapshot at ${SNAPSHOT_PATH}..."
        sudo btrfs subvolume snapshot "${mp}" "${SNAPSHOT_PATH}"
        if [ $? -ne 0 ]; then
            echo "  ❌ ERROR: Failed to create new snapshot."
        else
            echo "  ✅ Snapshot created successfully."
        fi
    else
        echo "  ⚠️  Could not determine disk type for ${mp} with label ${LABEL}. Skipping."
    fi
done

echo "✨ --- Snapshot creation process complete ---"
