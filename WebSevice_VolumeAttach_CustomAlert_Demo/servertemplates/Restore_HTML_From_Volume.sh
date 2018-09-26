#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: Restore HTML From Volume
# Description: Mounts an attached volume containing a snapshot and restores the HTML
#   files from it to the working set.
# Inputs:
#   DISK_DEVICE:
#     Category: Uncategorized
#     Input Type: single
#     Required: true
#     Advanced: false
# Attachments: []
# ...

# create mount point directory
mount_point="/restore"
mkdir ${mount_point}

# mount volume to filesystem
mount $DISK_DEVICE ${mount_point}

# sync the restored files over to the mounted folder
rsync -av ${mount_point}/html /data

# unmount the volume
umount ${mount_point}
