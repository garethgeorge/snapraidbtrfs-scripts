#!/bin/bash

#
# This script formats a specified block device with the Btrfs filesystem,
# assigns it a label based on the SnapRAID naming convention (oceanp## or oceand##),
# and creates a corresponding mount point in /mnt/.
#
# It can optionally encrypt the device using LUKS.
#
# WARNING: This is a DESTRUCTIVE operation and will erase all data on the disk.
#
# Usage:
#   sudo ./format-disk.sh /dev/sdX --data
#   sudo ./format-disk.sh /dev/sdY --parity
#   sudo ./format-disk.sh /dev/sdZ --data /path/to/luks.key
#

set -e # Exit immediately if a command exits with a non-zero status.

# --- Argument Validation ---

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run with root privileges. Please use sudo."
  exit 1
fi

# Check argument count
if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
    echo "Usage: $0 /dev/disk --<type> [luks_password_file]"
    echo "  <type> must be either --data or --parity"
    echo "  luks_password_file is an optional path to a key file for LUKS encryption."
    exit 1
fi

DEVICE=$1
TYPE_FLAG=$2
LUKS_KEY_FILE=/mnt/usb-secrets/ocean_luks_key
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
if [ -n "$LUKS_KEY_FILE" ]; then
echo "  Encryption:       LUKS (using key at ${LUKS_KEY_FILE})"
fi
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

if [ -n "$LUKS_KEY_FILE" ]; then
    # Encrypted disk setup
    echo "  1/4: Creating LUKS encrypted container on ${DEVICE}..."
    if ! cryptsetup luksFormat --type luks2 --batch-mode --key-file "$LUKS_KEY_FILE" "$DEVICE"; then
        echo "❌ ERROR: Failed to create LUKS container. Aborting."
        exit 1
    fi
    echo "      ✅ LUKS container created."

    echo "  2/4: Opening LUKS container as '${LABEL}'..."
    if ! cryptsetup open --key-file "$LUKS_KEY_FILE" "$DEVICE" "$LABEL"; then
        echo "❌ ERROR: Failed to open LUKS container. Aborting."
        exit 1
    fi
    echo "      ✅ Container opened at /dev/mapper/${LABEL}."

    MAPPED_DEVICE="/dev/mapper/${LABEL}"
    echo "  3/4: Formatting ${MAPPED_DEVICE} with Btrfs and label '${LABEL}'..."
    if ! mkfs.btrfs -f -L "$LABEL" "$MAPPED_DEVICE"; then
        echo "❌ ERROR: Failed to format the mapped device. Aborting."
        # Close the container on failure
        cryptsetup close "$LABEL"
        exit 1
    fi
    echo "      ✅ Mapped device formatted successfully."

    echo "  4/4: Creating mount point at ${MOUNT_POINT}..."
    if ! mkdir -p "$MOUNT_POINT"; then
        echo "❌ ERROR: Failed to create mount point. You may need to create it manually."
        # Close the container on failure
        cryptsetup close "$LABEL"
        exit 1
    fi
    echo "      ✅ Mount point created."

    # Close the container; it will be reopened on boot via crypttab
    echo "  -> Closing LUKS container '${LABEL}'."
    cryptsetup close "$LABEL"

else
    # Unencrypted disk setup
    echo "  1/2: Formatting ${DEVICE} with Btrfs and label '${LABEL}'..."
    if ! mkfs.btrfs -f -L "$LABEL" "$DEVICE"; then
        echo "❌ ERROR: Failed to format the disk. Aborting."
        exit 1
    fi
    echo "      ✅ Disk formatted successfully."

    echo "  2/2: Creating mount point at ${MOUNT_POINT}..."
    if ! mkdir -p "$MOUNT_POINT"; then
        echo "❌ ERROR: Failed to create mount point. You may need to create it manually."
        exit 1
    fi
    echo "      ✅ Mount point created."
fi


echo
echo "✨ --- Process Complete --- ✨"
echo "The disk is ready."
echo "To ensure it mounts automatically on boot, run the 'create-fstab.sh' script"
echo "to generate the necessary /etc/fstab and /etc/crypttab entries."