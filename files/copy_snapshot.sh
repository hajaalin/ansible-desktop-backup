#!/bin/bash
##############################################################################
# make_snapshot.bash  -- version 0.1 -- 2002-12-09
# Type `./make_snapshot.bash -h` for more information.
# by Elio Pizzottelli, elio@tovel.it
##############################################################################
#
# rotating-filesystem-snapshot utility
#
# Copyright (C) 2002 Elio Pizzottelli elio@tovel.it
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# CREDITS/HISTORY
#
# ##########################################################################
# # mikes handy rotating-filesystem-snapshot utility                       #
# # RCS info: $Id: make_snapshot.sh,v 1.6 2002/04/06 04:20:00 mrubel Exp $ #
# # http://www.mikerubel.org/computers/rsync_snapshots/                    #
# ##########################################################################

# Modifications: 2015-12-30 - Harri Jäälinoja

##############################################################################
# system commands used by this script
#

ID=/usr/bin/id;
ECHO=/bin/echo;

SEQ=/usr/bin/seq;
GETOPT=/usr/bin/getopt;
GREP=/bin/grep;

MOUNT=/bin/mount;
RM=/bin/rm;
MV=/bin/mv;
CP=/bin/cp;
TOUCH=/bin/touch;

##############################################################################
# check if arguments are given
#

if [ $# = 0 ] ; then
    $ECHO Error: no arguments. Type $0 -h for help. ;
    exit;
fi

##############################################################################
# parsing arguments and options
#

TEMP=`$GETOPT -o h::d:N:l:f: -- "$@"`

if [ $? != 0 ] ; then
    $ECHO Error parsing arguments and options ;
    exit ;
fi

# Note the quotes around `$TEMP': they are essential!

eval set -- "$TEMP"

while true ; do
    case $1 in
        -d) DESTINATION_DIR="$2";
           shift 2 ;;
           -N) BACKUP_NAME="$2";
           shift 2 ;;
           -O) BACKUP_NAME_ORIG="$2";
           shift 2 ;;
        -l) case $2 in
               [0-9]*) BACKUP_NUMBER="$2";
                       if [ $BACKUP_NUMBER -lt 2 ] ; then
                           $ECHO Error: Option -l requires a numeric argument greater than 2 ;
                           exit;
                       fi;
                       shift 2;;
               *) $ECHO Error: Option -l requires a numeric argument greater than 2;
                  exit;;
           esac;;
        -f) EXCLUDE_FILE="$2";
           shift 2;;
        --) shift ; break ;;
        -h) echo "
Usage:

 make_snapshot.bash device mount_point source_dir [-d destination_dir]
    [-N backup_name] [-m max_backups] [-f exclude_file]

Explanation:

 device:           a partition devica
 mount_point:      a valid mount point
 source_dir:       the directory to bakup

 destination_dir: a optional destination dir, default it is unset
                    (starting from the mount_point)
 backup_name:       a name for the backup, default BACKUP
 backup_level:      the number of backups to preseve, default 5, min 2
 exclude_file:     a file for rsync --exclude-from, default it is unset

Example:

 make_snapshot.bash /dev/hdd15 /root/backup /home/;
 make_snapshot.bash /dev/hdd15 /root/backup /home/ -d home;
 make_snapshot.bash /dev/hdd15 /root/backup /home/ -d home -O hourly -N daily
 make_snapshot.bash /dev/hdd15 /root/backup /home/ -d home -N daily -l 10;
 make_snapshot.bash /dev/hdd15 /root/backup /home/ -d home -N daily -l 10 \\
     -f /root/make_snapshot_exclude

Example Crontab-lines:

0 8-18/2 * * * make_snapshot.bash /dev/hdd15 /root/backup /home/ -d home -N hourly -m 10;
0 12 * * *  make_snapshot.bash /dev/hdd15 /root/backup /home/ -d home -N daily -m 10;
0 14 * * *  make_snapshot.bash /dev/hdd15 /root/backup /www/ -d /web/www -N daily -m 5;

BUGS:

 This is a rsync (missing) feature, the description is made by Mike Rubel:
  This snapshot system does not properly maintain old ownerships/permissions;
  if a file's ownership or permissions are changed in place, then the new
  ownership/permissions will apply to older snapshots as well.
  This is because rsync does not unlink files prior to changing them if the
  only changes are ownership/permission. Thanks to J.W. Schultz for pointing
  this out. This is not a problem for me, but slightly more complicated
  workarounds are possible.

TODO:

 Simplify some code.
 Redirec the error messages.
 exit and exit 1.
 use ssync?
 device as option an permit simple source to destination usage...?

 This script will be very unefficent if you move some big files from a dir to
 another or if you move or rename big files and dir.
 I think that it would be possible with GNU/diff to find the moved file or dird
 an take a note of move in a simple file in this way
 $ find_moved_files source_dir bakups_dir [-m minimun_size]
 $ find_moved_dirs source_dir bakups_dir [-m minimun_size]
 # minimum file check size : 100k
 file dir/file # timestamp
 file1 dir/file1 #timestamp

";
            exit;;
        *) $ECHO Error: unrecognized option. Type $0 -h for more information ;
           exit;;
    esac
done

if [ $# != 3 ] ; then
    $ECHO Error: invalid number of arguments.;
    exit;
fi

MOUNT_DEVICE_UUID=$1;
MOUNT_POINT_RW=$2;
SOURCE_DIR=$3;


##############################################################################
# make sure we're running as root
#

if (( `$ID -u` != 0 )); then
    $ECHO Error: must be root. Exiting... ;
    exit;
fi


##############################################################################
# check the arguments and the options
#

MOUNT_DEVICE=`blkid | egrep $MOUNT_DEVICE_UUID |cut -d: -f1`
#echo MOUNT_DEVICE $MOUNT_DEVICE
if [ -z $MOUNT_DEVICE ] ; then
  $ECHO Error: "Didn't find device corresponding to $MOUNT_DEVICE_UUID."
  exit;
fi


if [ ! -b $MOUNT_DEVICE ] ; then
    $ECHO Error: $MOUNT_DEVICE ins\'t a valid device. Exiting ;
    exit ;
fi

if [ ! -d $MOUNT_POINT_RW ] ; then
    if [ -e $MOUNT_POINT_RW ] ; then
        $ECHO Error: $MOUNT_POINT_RW isn\'t a directory. Exiting ;
        exit ;
    fi
    $ECHO Notice: $MOUNT_POINT_RW don\'t exist. Creating... ;
    mkdir -p -m 755 $MOUNT_POINT_RW ;
fi

##############################################################################
# attempt to remount the RW mount point as RW; else abort
#

$MOUNT -t ext2 -o remount,rw $MOUNT_DEVICE $MOUNT_POINT_RW ;

if (( $? )); then
    $ECHO Error: could not remount $MOUNT_POINT_RW readwrite ;
    exit ;
fi

##############################################################################
# continue check the arguments and the options
#

if [ ! -d $SOURCE_DIR ] ; then
    $ECHO $SOURCE_DIR isn\'t a valid directory. Exiting... ;
    exit ;
fi

##############################################################################
# setting optionals settings
#

if [ -z $BACKUP_NAME ] ; then
    BACKUP_NAME=BACKUP;
fi

if [ -z $BACKUP_NAME_ORIG ] ; then
    BACKUP_NAME_ORIG="hourly";
fi

if [ ! -z $($ECHO $BACKUP_NAME | $GREP "\/" ) ] ; then
    $ECHO Error: backup_name: $BACKUP_NAME can\'t be a subdirectory ;
    exit;
fi


if [ ! -d $MOUNT_POINT_RW/$DESTINATION_DIR/ ] ; then
    if [ -e $MOUNT_POINT_RW/$DESTINATION_DIR/ ] ; then
        ECHO Error: $MOUNT_POINT_RW/$DESTINATION_DIR/ isn\'t a directory. Exiting ;
        exit ;
    fi
    $ECHO Notice: $MOUNT_POINT_RW/$DESTINATION_DIR/ don\'t exist. Creating... ;
    mkdir -p -m 755 $MOUNT_POINT_RW/$DESTINATION_DIR/ ;
fi


##############################################################################
# setting optionals settings
#

if [ -z "$BACKUP_NUMBER" ] ; then
    BACKUP_NUMBER=5;
fi


##############################################################################
# rotating snapshots
# delete the oldest snapshot in background, if it exists:
#

if [ -d $MOUNT_POINT_RW/$DESTINATION_DIR/$BACKUP_NAME.$BACKUP_NUMBER ] ; then
    $MV $MOUNT_POINT_RW/$DESTINATION_DIR/$BACKUP_NAME.$BACKUP_NUMBER \
        $MOUNT_POINT_RW/$DESTINATION_DIR/$BACKUP_NAME.$BACKUP_NUMBER.delete
    $RM -rf $MOUNT_POINT_RW/$DESTINATION_DIR/$BACKUP_NAME.$BACKUP_NUMBER.delete &
fi


##############################################################################
# shift the middle snapshots(s) back by one, if they exist
#

for i in `$SEQ $BACKUP_NUMBER -1 2`; do
    iminus=$(($i-1)) ;
    if [ -d $MOUNT_POINT_RW/$DESTINATION_DIR/$BACKUP_NAME.$iminus ] ; then
        $MV $MOUNT_POINT_RW/$DESTINATION_DIR/$BACKUP_NAME.$iminus \
            $MOUNT_POINT_RW/$DESTINATION_DIR/$BACKUP_NAME.$i ;
    fi
done


##############################################################################
# make a hard-link-only (except for dirs) copy of the latest snapshot,
# if that exists
#

if [ -d $MOUNT_POINT_RW/$DESTINATION_DIR/$BACKUP_NAME_ORIG.0 ] ; then
    $CP -al $MOUNT_POINT_RW/$DESTINATION_DIR/$BACKUP_NAME_ORIG.0 \
            $MOUNT_POINT_RW/$DESTINATION_DIR/$BACKUP_NAME.1 ;
fi

##############################################################################
# update the mtime of $BACKUP_NAME.0 to reflect the snapshot time
#

$TOUCH $MOUNT_POINT_RW/$DESTINATION_DIR/$BACKUP_NAME.1 ;


##############################################################################
# wait for rm in background finish
#

wait ;

##############################################################################
# remount the RW snapshot mountpoint as readonly
#

$MOUNT -o remount,ro $MOUNT_DEVICE $MOUNT_POINT_RW ;
if (( $? )); then
    $ECHO Error: could not remount $MOUNT_POINT_RW readonly ;
    exit ;
fi


#
# EOF
##############################################################################
