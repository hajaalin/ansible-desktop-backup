#!/bin/bash


# daily copy of hourly.0 to weekly.0
ionice -c 3 {{ script_main }} \
{{ backup_drive_uuid }} {{ backup_mount_point }} \
/home,/ \
-d {{ backup_name }} \
-N weekly \
-O hourly \
-l {{ keep_weekly }} \
-f {{ exclude_file }}

# This is to drive user applications back out of swap after backup.
# Improves responsiveness when user returns.
swapoff -a > /dev/null 2>&1 || true
swapon -a > /dev/null 2>&1 || true
