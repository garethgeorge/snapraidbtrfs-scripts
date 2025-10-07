## Snapraid Managment Scripts

To use start by formatting your disks to use btrfs. You will divide your disks into parity and data disks.
I recommend starting with at least 1 parity disk and any number of data disks (at least 1, but 1 is really 
a fine place to start if you intend to expand later).

Format your data disks (note the oceandNN naming scheme where the 'd' denotes that it is a data disk and the number is the disk index)
```
sudo mkfs.btrfs -L oceand01 /dev/sdi1
```

Format your parity disks (note the oceanpNN naming scheme where the 'p' denotes that it is a parity disk and the nubmer is the disk index).

```
sudo mkfs.btrfs -L oceanp01 /dev/sdj1
```

### Creating your fstab

To start run `sh create-fstab.sh` and paste the output into your `/etc/fstab.sh` , this will define a series
of fstab entries to mount your disks into `/mnt/oceanpNN` or `/mnt/oceandNN` folders, you will need to create a folder
for each entry manually.

It will also create a mergerfs entry which will create a merged filesystem from the provided disks.

### Creating your snapraid configuration

To create your snapraid configuration run `sh create-snapraid-conf.sh` and paste the output into `/etc/snapraid.conf`.

This configuration can be regenerated at any time. It will list your parity disks as parity in the config, data disks as data as expected.
It will also configure snapraid to place a content manifest in the root of every data disk in the array for maximum resiliance. The content
index must be avialable to successfully execute snapraid restores, etc.

### Running snapraid sync

To safely run syncs while the disk is in use, we use btrfs snapshots to create a snapshot of each disk, and then run 
sync safely off of these point in time snapshots which should _not_ be modified directly. 

To run a sync run the following two commands:
```
sh create-snapraid-snapshot.sh
sudo snapraid sync -c /etc/snapraid.conf
```
