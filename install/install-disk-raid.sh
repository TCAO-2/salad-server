#!/bin/bash

# Stop the script on error.
set -e





################################################################################
# Parameters
################################################################################

# Name of the logical volume to create. The partition will be suffixed by "p1".
RAID_NAME="md0"

# Name of the physical volumes to use.
RAID_DEVICES="/dev/vdb /dev/vdc /dev/vdd /dev/vde"

# RAID events will be reported using this script.
ALERT_SCRIPT="/opt/salad-server/scripts/mdadm-event.sh"





################################################################################
# Main execution
################################################################################

# Create the RAID5 array.
raid_dev_nb=$(echo $RAID_DEVICES | wc -w)
mdadm --create --verbose /dev/${RAID_NAME} --level=5 --raid-devices=$raid_dev_nb $RAID_DEVICES

# Create a Linux filesystem partition.
echo "type=83" | sfdisk /dev/${RAID_NAME}
partition=${RAID_NAME}p1

# Format the partition in ext4.
mkfs.ext4 /dev/${partition}

# Mount the partition and enable auto mount on startup.
# As we will only store data here, I passed the noexec option.
mkdir /mnt/${partition}
uuid=$(blkid | grep $partition | grep -oP '(?<= UUID=")[^"]*(?=")')
echo "UUID=$uuid /mnt/${partition} ext4 defaults,noexec 0 2" >> /etc/fstab
systemctl daemon-reload
mount /mnt/${partition}





################################################################################
# Setup RAID events alerting
################################################################################

echo "PROGRAM ${ALERT_SCRIPT}" >> /etc/mdadm/mdadm.conf
update-initramfs -u
