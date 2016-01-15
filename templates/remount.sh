#!/bin/bash

MOUNT_DEVICE_UUID={{ backup_drive_uuid }}
MOUNT_POINT={{ backup_mount_point }}
FS_TYPE={{ fs_type }}

BLKID=/sbin/blkid
EGREP=/bin/egrep
MOUNT=/bin/mount

# mode to mount, ro or rw
MODE=$1

MOUNT_DEVICE=`$BLKID | $EGREP $MOUNT_DEVICE_UUID |cut -d: -f1`
#echo MOUNT_DEVICE $MOUNT_DEVICE
if [ -z $MOUNT_DEVICE ] ; then
  $ECHO Error: "Didn't find device corresponding to $MOUNT_DEVICE_UUID."
  exit;
fi

if [ ! -b $MOUNT_DEVICE ] ; then
    $ECHO Error: $MOUNT_DEVICE ins\'t a valid device. Exiting ;
    exit ;
fi

if [ ! -d $MOUNT_POINT ] ; then
    if [ -e $MOUNT_POINT ] ; then
        $ECHO Error: $MOUNT_POINT isn\'t a directory. Exiting ;
        exit ;
    fi
fi


##############################################################################
# check that device is or can be mounted the mount point
#
$EGREP "^$MOUNT_DEVICE" /proc/mounts | $EGREP -q "$MOUNT_POINT" || $MOUNT -t $FS_TYPE -o ro $MOUNT_DEVICE $MOUNT_POINT

if (( $? )); then
    $ECHO Error: could not mount $MOUNT_DEVICE to $MOUNT_POINT ;
    exit ;
fi


##############################################################################
# attempt to remount the device in the requested mode; else abort
#

$MOUNT -t $FS_TYPE -o remount,$MODE $MOUNT_DEVICE $MOUNT_POINT ;

if (( $? )); then
    $ECHO Error: could not remount $MOUNT_POINT $MODE ;
    exit ;
fi
