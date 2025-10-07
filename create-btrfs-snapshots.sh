#!/bin/bash

#
# This script finds all ocean[dp]## btrfs mounts and creates a
# consistent, read-only snapshot named '_snapraid_sync' on each one.
# This should be run immediately before a 'snapraid sync' command.
#

SNAPRAID_DIR=".snapraid"
SNAPSHOT_NAME=".snapraid/btrfs_checkpoint"
LABEL_PATTERN="^ocean[dp][0-9][0-9]$"
FSTYPE="btrfs"

echo "📸 --- Preparing SnapRAID Btrfs Snapshots ---"

# Find all relevant mount points using lsblk
MOUNT_POINTS=$(lsblk -n -o LABEL,FSTYPE,MOUNTPOINT | awk -v pattern="$LABEL_PATTERN" -v fstype="$FSTYPE" '
    $1 ~ pattern && $2 == fstype && $3 != "" { print $3 }
' | sort)

if [ -z "$MOUNT_POINTS" ]; then
    echo "⚠️  No ocean disks found. Exiting."
    exit 1
fi

for mp in $MOUNT_POINTS; do
    SNAPSHOT_PATH="${mp}/${SNAPSHOT_NAME}"

    echo "🧭 Processing disk at mount point: ${mp}"

    # Ensure the .snapraid directory exists
    if [ ! -d "${mp}/${SNAPRAID_DIR}" ]; then
    echo "  📁 Creating directory ${mp}/${SNAPRAID_DIR}..."
        mkdir -p "${mp}/${SNAPRAID_DIR}"
        if [ $? -ne 0 ]; then
            echo "  ❌ ERROR: Failed to create directory. Please check permissions."
            continue
        fi
    fi

    # Check for and delete the old snapshot if it exists
    if [ -d "${SNAPSHOT_PATH}" ]; then
        echo "  🗑️  Deleting old snapshot at ${SNAPSHOT_PATH}..."
        sudo btrfs subvolume delete "${SNAPSHOT_PATH}"
        if [ $? -ne 0 ]; then
            echo "  ❌ ERROR: Failed to delete old snapshot. Please check permissions."
            continue
        fi
    fi

    # Create the new read-only snapshot of the mount point's root
    echo "  🆕 Creating new read/write snapshot at ${SNAPSHOT_PATH}..."
    sudo btrfs subvolume snapshot "${mp}" "${SNAPSHOT_PATH}"
    if [ $? -ne 0 ]; then
        echo "  ❌ ERROR: Failed to create new snapshot."
    else
        echo "  ✅ Snapshot created successfully."
    fi
done

echo "✨ --- Snapshot creation process complete ---"
