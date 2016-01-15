#!/bin/bash

{{ script_remount }} rw

ionice -c 3 rsnapshot sync && rsnapshot hourly

{{ script_remount }} ro

# This is to drive user applications back out of swap after backup.
# Improves responsiveness when user returns.
swapoff -a > /dev/null 2>&1 || true
swapon -a > /dev/null 2>&1 || true
