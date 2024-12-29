#!/bin/bash

# Stop the script on error.
set -e





################################################################################
# Constants
################################################################################

CPU_THRESHOLD_WARN=70
CPU_THRESHOLD_ERROR=85

DISK_THRESHOLD_WARN=45
DISK_THRESHOLD_ERROR=60





################################################################################
# Main
################################################################################

function logger {
    message=$1
    loglevel=$2
    /opt/salad-server/scripts/logger.sh "temperatures" "$message" "$loglevel"
}

# CPU temperatures.
cpu_temp=$(cat /sys/class/thermal/thermal_zone*/temp \
    | sort -n | tail -n 1 | grep -o "^..")

if [ $cpu_temp -gt $CPU_THRESHOLD_ERROR ]; then
    logger "CPU temp ${cpu_temp} > ${CPU_THRESHOLD_ERROR}" "ERROR"
elif [ $cpu_temp -gt $CPU_THRESHOLD_WARN ]; then
    logger "CPU temp ${cpu_temp} > ${CPU_THRESHOLD_WARN}" "WARN"
else
    logger "CPU temp ${cpu_temp}" "INFO"
fi

# Disks temperatures.
devices=$(smartctl --scan | grep -o "^[^ ]*")
for device in $devices; do
    if hdparm -C $device | grep standby &> /dev/null; then
        # Do not read the temp from a standby disk as it would wake it up.
        logger "Disk ${device} temp NaN (in standby)" "INFO"
    else
        disk_temp=$(smartctl -aj ${device} | jq .temperature.current)
        if [ $disk_temp -gt $DISK_THRESHOLD_ERROR ]; then
            logger "Disk ${device} temp ${disk_temp} > ${DISK_THRESHOLD_ERROR}" "ERROR"
        elif [ $disk_temp -gt $DISK_THRESHOLD_WARN ]; then
            logger "Disk ${device} temp ${disk_temp} > ${DISK_THRESHOLD_WARN}" "WARN"
        else
            logger "Disk ${device} temp ${disk_temp}" "INFO"
        fi
    fi
done
