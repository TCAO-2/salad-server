#!/bin/bash

# Stop the script on error.
set -e

LOGFILE_NAME="temperatures"

function logger {
    local message=$1
    local loglevel=$2
    local filename=$3
    if [ -z "${filename}" ]; then
        /opt/salad-server/scripts/logger.sh "$LOGFILE_NAME" "$message" "$loglevel" \
        || echo "[${loglevel}] ${message}"
    else
        /opt/salad-server/scripts/logger.sh "${LOGFILE_NAME}/${filename}" "$message" "$loglevel" \
        || echo "[${loglevel}] ${message}"
    fi
}

trap 'logger "Unexpected error at line ${LINENO}: \"${BASH_COMMAND}\" returns ${?}." "ERROR"' ERR





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

# CPU temperatures.
cpu_temp=$(cat /sys/class/thermal/thermal_zone*/temp \
    | sort -n | tail -n 1 | grep -o "^..")

if [ $cpu_temp -gt $CPU_THRESHOLD_ERROR ]; then
    logger "CPU temp ${cpu_temp} > ${CPU_THRESHOLD_ERROR}" "ERROR" "CPU"
elif [ $cpu_temp -gt $CPU_THRESHOLD_WARN ]; then
    logger "CPU temp ${cpu_temp} > ${CPU_THRESHOLD_WARN}" "WARN" "CPU"
else
    logger "CPU temp ${cpu_temp}" "INFO" "CPU"
fi

# Checks that we are using the root account.
if ! [ "$(whoami)" == "root" ]; then
    logger "Must be root for using smartctl." "ERROR"; exit 12
fi

# Disks temperatures.
devices=$(/sbin/smartctl --scan | grep -o "^[^ ]*")
for device in $devices; do
    if /sbin/hdparm -C $device | grep standby &> /dev/null; then
        # Do not read the temp from a standby disk as it would wake it up.
        logger "Disk ${device} temp NaN (in standby)" "VERB"
    else
        # SMART overview.
        {
            smart_report=$(/sbin/smartctl -aj $device)
            # Get the disk model name and S/N for physical identification.
            model_name=$(echo $smart_report | jq -r .model_name)
            serial_number=$(echo $smart_report | jq -r .serial_number)
            # Get the disk protocol (ATA or NVMe).
            disk_protocol=$(echo $smart_report | jq -r .device.protocol)
            # Get the disk temperature.
            disk_temp=$(echo $smart_report | jq .temperature.current)
        } || {
            logger "Disk ${device} SMART not enabled" "ERROR"
        }
        device_name=$(echo "${model_name} ${serial_number} ${disk_protocol}" | sed 's/[^a-zA-Z0-9]/_/g')
        if [ $disk_temp -gt $DISK_THRESHOLD_ERROR ]; then
            logger "Disk ${device} temp ${disk_temp} > ${DISK_THRESHOLD_ERROR}" "ERROR" "$device_name"
        elif [ $disk_temp -gt $DISK_THRESHOLD_WARN ]; then
            logger "Disk ${device} temp ${disk_temp} > ${DISK_THRESHOLD_WARN}" "WARN" "$device_name"
        else
            logger "Disk ${device} temp ${disk_temp}" "INFO" "$device_name"
        fi
    fi
done
