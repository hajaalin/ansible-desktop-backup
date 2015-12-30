#!/bin/bash

# daily backup of /home
ionice -c 3 {{ script_main }} \
{{ backup_drive_uuid }} {{ backup_mount_point }} \
/home/ \
-d {{ backup_name }} \
-N daily \
-l {{ keep_daily }} \
-f {{ exclude_file }}

# daily backup of /
ionice -c 3 {{ script_main }} \
{{ backup_drive_uuid }} {{ backup_mount_point }} \
/ \
-d {{ backup_name }} \
-N daily \
-l {{ keep_daily }} \
-f {{ exclude_file }}

# This is to drive user applications back out of swap after backup.
# Improves responsiveness when user returns.
swapoff -a > /dev/null 2>&1 || true
swapon -a > /dev/null 2>&1 || true
