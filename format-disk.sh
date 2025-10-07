#!/bin/bash

#
# This script formats a specified block device with the Btrfs filesystem,
# assigns it a label based on the SnapRAID naming convention (oceanp## or oceand##),
# and creates a corresponding mount point in /mnt/.
#
# WARNING: This is a DESTRUCTIVE operation and will erase all data on the disk.
#
# Usage:
#   sudo ./format-disk.sh /dev/sdX --data
#   sudo ./format-disk.sh /dev/sdY --parity
#

set -e # Exit immediately if a command exits with a non-zero status.

# --- Argument Validation ---

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run with root privileges. Please use sudo."
  exit 1
fi

# Check argument count
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 /dev/disk --<type>"
    echo "  <type> must be either --data or --parity"
    exit 1
fi

DEVICE=$1
TYPE_FLAG=$2
PREFIX=""

# Validate device path
if [ ! -b "$DEVICE" ]; then
    echo "❌ Error: Device '$DEVICE' is not a valid block device."
    exit 1
fi

# Determine label prefix from flag
case "$TYPE_FLAG" in
    --data)
        PREFIX="oceand"
        ;;
    --parity)
        PREFIX="oceanp"
        ;;
    *)
        echo "❌ Error: Invalid type. Use --data or --parity."
        exit 1
        ;;
esac

# --- Find Next Available Disk ID ---

NEXT_ID=""
for i in $(seq -f "%02g" 1 99); do
    if [ ! -e "/mnt/${PREFIX}${i}" ]; then
        NEXT_ID=$i
        break
    fi
done

if [ -z "$NEXT_ID" ]; then
    echo "❌ Error: No available disk IDs found for prefix '${PREFIX}'. All slots from 01-99 are taken."
    exit 1
fi

LABEL="${PREFIX}${NEXT_ID}"
MOUNT_POINT="/mnt/${LABEL}"

# --- User Confirmation ---

echo "⚠️  --- WARNING: DESTRUCTIVE OPERATION --- ⚠️"
echo "This script will format the disk and ERASE ALL DATA on it."
echo
echo "  Disk to format:   ${DEVICE}"
echo "  Filesystem:       btrfs"
echo "  New label:        ${LABEL}"
echo "  Mount point to be created: ${MOUNT_POINT}"
echo

read -p "Are you absolutely sure you want to continue? (y/N): " CONFIRMATION
if [[ ! "$CONFIRMATION" =~ ^[Yy]$ ]]; then
    echo "🛑 Aborted by user."
    exit 0
fi

# --- Execution ---

echo "🚀 Starting formatting process..."

# 1. Format the disk with the new label
echo "  1/2: Formatting ${DEVICE} with Btrfs and label '${LABEL}'..."
if ! mkfs.btrfs -f -L "$LABEL" "$DEVICE"; then
    echo "❌ ERROR: Failed to format the disk. Aborting."
    exit 1
fi
echo "      ✅ Disk formatted successfully."

# 2. Create the mount point
echo "  2/2: Creating mount point at ${MOUNT_POINT}..."
if ! mkdir -p "$MOUNT_POINT"; then
    echo "❌ ERROR: Failed to create mount point. You may need to create it manually."
    exit 1
fi
echo "      ✅ Mount point created."

echo
echo "✨ --- Process Complete --- ✨"
echo "The disk is ready. To mount it, you can run:"
echo "  sudo mount -L ${LABEL} ${MOUNT_POINT}"
echo
echo "To ensure it mounts automatically on boot, consider adding it to /etc/fstab."
echo "You can use the 'create-fstab.sh' script to help generate the fstab entry."
