#!/bin/bash
#
# This script provisions a new disk for the ocean storage pool.
# WARNING: THIS IS A DESTRUCTIVE OPERATION AND WILL ERASE ALL DATA ON THE TARGET DISK.
#
# It performs the following actions:
# 1. Wipes the disk by creating a new GPT partition table.
# 2. Creates a single partition spanning the entire disk.
# 3. Assigns a GPT partition label to the new partition (e.g., "oceand01").
# 4. Initializes a LUKS2 encrypted container on the partition.
# 5. Creates a Btrfs filesystem inside the LUKS container.
# 6. Assigns a Btrfs filesystem label that matches the partition label.
#

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
LUKS_KEY_FILE="/etc/keys/ocean_luks_key"
LABEL_PATTERN="^ocean[dp][0-9][0-9]$"

# --- Pre-flight Checks ---

# 1. Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# 2. Check for correct number of arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <device> <label>"
    echo "Example: $0 /dev/sdh oceand01"
    exit 1
fi

DEVICE="$1"
LABEL="$2"

# 3. Validate the device path
if ! [ -b "$DEVICE" ]; then
    echo "Error: Device '$DEVICE' is not a valid block device." >&2
    exit 1
fi

# 4. Validate the label format
if ! [[ "$LABEL" =~ $LABEL_PATTERN ]]; then
    echo "Error: Label '$LABEL' does not match the required format 'ocean[d/p]##' (e.g., oceand01, oceanp01)." >&2
    exit 1
fi

# 5. Final confirmation from the user
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "This script is about to permanently erase all data on the disk: $DEVICE."
echo "It will be partitioned, encrypted with LUKS, and formatted with Btrfs."
echo "Partition Label: $LABEL"
echo "Btrfs Label:     $LABEL"
echo ""
read -p "Are you absolutely sure you want to continue? (yes/no): " CONFIRMATION
if [ "$CONFIRMATION" != "yes" ]; then
    echo "Operation cancelled."
    exit 0
fi

# --- Main Logic ---

echo "--- Starting disk formatting for $DEVICE with label $LABEL ---"

# 1. Wipe existing partition table and create a new GPT table
echo "1. Creating new GPT partition table on $DEVICE..."
parted -s "$DEVICE" mklabel gpt

# 2. Create a single partition spanning the entire disk and label it
echo "2. Creating and labeling partition..."
parted -s -a optimal "$DEVICE" mkpart "$LABEL" 0% 100%
# The partition device will be something like /dev/sdh1
PARTITION_DEVICE="${DEVICE}1" 
# Wait a moment for the kernel to recognize the new partition
sleep 2 
if ! [ -b "$PARTITION_DEVICE" ]; then
    # Handle NVMe devices which have a 'p' in their name (e.g., /dev/nvme0n1p1)
    PARTITION_DEVICE="${DEVICE}p1"
    if ! [ -b "$PARTITION_DEVICE" ]; then
        echo "Error: Could not find the new partition device. Looked for ${DEVICE}1 and ${DEVICE}p1." >&2
        exit 1
    fi
fi
echo "   New partition is at $PARTITION_DEVICE"

# 3. Initialize LUKS2 on the new partition
echo "3. Initializing LUKS2 container on $PARTITION_DEVICE..."
# The --batch flag is not supported on older cryptsetup versions, so we pipe "YES" instead.
echo "YES" | cryptsetup luksFormat --type luks2 "$PARTITION_DEVICE" "$LUKS_KEY_FILE"

# 4. Open the new LUKS container to format the inside
echo "4. Temporarily opening LUKS container as '$LABEL'..."
cryptsetup open "$PARTITION_DEVICE" "$LABEL" --key-file "$LUKS_KEY_FILE"
MAPPER_PATH="/dev/mapper/$LABEL"

# 5. Create the Btrfs filesystem inside the container
echo "5. Creating Btrfs filesystem on $MAPPER_PATH..."
# The -f flag is needed to format on a mapped device
mkfs.btrfs -f -L "$LABEL" "$MAPPER_PATH"

# 6. Close the LUKS container
echo "6. Closing LUKS container..."
cryptsetup close "$LABEL"

echo "--- Disk provisioning complete for $DEVICE ---"
echo "The disk is now ready to be used by the create-fstab.sh script."
