#!/bin/bash

# Add SMART selftest every months and check disk health every day.

# Stop the script on error.
set -e





################################################################################
# Constants
################################################################################

# These regex have to match only on physical disks.
DEV_REGEX=(
    "/dev/sd[a-z]"
    "/dev/nvme0n[0-9]"
)
SELFTEST_SCRIPT="/opt/salad-server/scripts/start-disk-selftest.sh"
HEALTH_SCRIPT="/opt/salad-server/scripts/check-disk-health.sh  "





################################################################################
# Main
################################################################################

dev_done=""     # Do not process disks already done.
install_nb=1    # Shift the SMART selftest day for each disk.

function install_check_disk_health {
    disk_id=$1
    # SMART selftest every month on the $install_nb-th day at 04:00.
    echo "0 4 ${install_nb} * * ${SELFTEST_SCRIPT} ${disk_id}"
    # Check disk health every day at 04:00.
    echo "0 4 * * * ${HEALTH_SCRIPT} ${disk_id}"
    install_nb=$((install_nb+1))
}

# Clean the crontab for old entries.


# Loop over physical disks in /dev/disk/by-id
for disk_id in $(ls -1 /dev/disk/by-id); do
    dev_path=$(realpath "/dev/disk/by-id/${disk_id}")
    for regex in "${DEV_REGEX[@]}"; do
        if ! echo "${dev_done}" | grep $dev_path > /dev/null \
                && echo $dev_path | grep "${regex}$" > /dev/null; then
            dev_done="${dev_done} ${dev_path}"
            install_check_disk_health $disk_id
        fi
    done
done
