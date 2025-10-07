# SnapRAID with Btrfs Management Scripts

Note: this is not a complete backup solution, this is just what I use on my personal NAS for a ~40 TB snapraid array. Use with caution.

This collection of scripts simplifies the setup and maintenance of a SnapRAID array that uses Btrfs-formatted disks. The key feature is the use of Btrfs snapshots to ensure a safe and consistent state for SnapRAID to sync from, even while the array is in use.

For anything mission critical, see https://github.com/garethgeorge/backrest for real backups.

## Features

- **Simplified Disk Formatting**: A guided script to format and label new data or parity disks.
- **Automatic `fstab` Generation**: Creates `/etc/fstab` entries for all your array disks and sets up a MergerFS pool.
- **Atomic Sync Operations**: Uses Btrfs snapshots to create a point-in-time, consistent view of all disks before running a sync.
- **Automated Workflow**: A single script handles snapshot creation, configuration generation, and the SnapRAID sync itself.

## Prerequisites

Before you begin, ensure the following utilities are installed on your system:
- `btrfs-progs` (for formatting and snapshotting)
- `snapraid`
- `mergerfs` (for pooling data disks)

## The Workflow

The process is broken down into three main stages:

1.  **One-Time Setup**:
    -   **Format Disks**: Use `format-disk.sh` for each new disk you add to your array.
    -   **Generate `fstab`**: Use `create-fstab.sh` to set up automatic mounting.
2.  **Ongoing Syncs**:
    -   **Run Sync**: Use the `run-sync.sh` script to perform routine SnapRAID syncs. This is the only command you'll need day-to-day.

---

## Step-by-Step Guide

### Step 1: Format Your Disks

For every new disk you want to add to the array, use the `format-disk.sh` script. This script will format the disk with Btrfs, assign a unique label (`oceand##` for data, `oceanp##` for parity), and create the corresponding mount point in `/mnt/`.

**This is a destructive operation.** The script includes a confirmation prompt to prevent accidental data loss.

**Usage:**

-   **To format a DATA disk:**
    ```bash
    sudo ./format-disk.sh /dev/sdX --data
    ```

-   **To format a PARITY disk:**
    ```bash
    sudo ./format-disk.sh /dev/sdY --parity
    ```

The script will automatically find the next available number (e.g., `oceand01`, `oceand02`, etc.).

### Step 2: Generate `fstab` for Automatic Mounting

After formatting your disks, you need to tell your system how to mount them on boot. The `create-fstab.sh` script automates this. It scans for all `ocean*` disks and generates the necessary entries for `/etc/fstab`.

**How to run:**

```bash
# First, run the script to see the proposed output
./create-fstab.sh

# If you are satisfied, append it to your system's fstab file
./create-fstab.sh | sudo tee -a /etc/fstab
```

This will:
1.  Create mount entries for each individual data and parity disk (e.g., `/mnt/oceand01`, `/mnt/oceanp01`).
2.  Create a [MergerFS](https://github.com/trapexit/mergerfs) entry to pool all your data disks together at `/ocean`.

After updating your fstab, you can mount everything with:
```bash
sudo mount -a
```

### Step 3: Run a SnapRAID Sync

The `run-sync.sh` script is an all-in-one command that orchestrates the entire sync process. You should run this script for your initial sync and for all subsequent syncs.

**Usage:**

```bash
sudo ./run-sync.sh
```

This master script performs the following actions in sequence:
1.  **Creates Btrfs Snapshots**: It calls `create-btrfs-snapshots.sh` to create a temporary, consistent snapshot of each data and parity disk.
2.  **Generates SnapRAID Config**: It calls `create-snapraid-conf.sh` to generate a fresh `/etc/snapraid.conf` file that points to these new snapshots.
3.  **Runs SnapRAID Sync**: It executes the `snapraid sync` command, which reads from the consistent snapshots, not the live filesystem.

This is the only command you need for routine parity updates.

## Automation

You can easily automate your syncs by creating a cron job to run the `run-sync.sh` script on a schedule.

For example, to run a sync every night at 3:00 AM, edit your crontab (`sudo crontab -e`) and add:

```cron
0 3 * * * /path/to/your/scripts/run-sync.sh
```

## Script Details

-   `format-disk.sh`: **(Setup)** Formats, labels, and creates a mount point for a new disk.
-   `create-fstab.sh`: **(Setup)** Generates `/etc/fstab` entries for all array disks and a MergerFS pool.
-   `create-btrfs-snapshots.sh`: **(Sync Component)** Creates snapshots of all disks for a consistent sync.
-   `create-snapraid-conf.sh`: **(Sync Component)** Generates a `snapraid.conf` that points to the snapshots.
-   `run-sync.sh`: **(Main Script)** Orchestrates the entire snapshot and sync process.
