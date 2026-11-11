#!/bin/bash

# Stop the script on error.
set -e

LOGFILE_NAME="temperatures"

CHECK_ACTIVITY=/opt/salad-server/scripts/check-disk-activity.sh
STANDBY_DELAY=600 # In seconds, setup on install with hdparm.
JSON_OUTPUT=1

function logger {
    if [ $JSON_OUTPUT -eq 1 ]; then
        local message=$1
        local loglevel=$2
        local filename=$3
        if [ -z "${filename}" ]; then
            /opt/salad-server/scripts/logger.sh "$LOGFILE_NAME" "$message" "$loglevel" 2>/dev/null \
            || echo "[${loglevel}] ${message}"
        else
            /opt/salad-server/scripts/logger.sh "${LOGFILE_NAME}/${filename}" "$message" "$loglevel" 2>/dev/null \
            || echo "[${loglevel}] ${message}"
        fi
    fi
}

function json_output {
    if [ $JSON_OUTPUT -eq 0 ]; then
        echo $json
    fi
}

trap 'logger "Unexpected error at line ${LINENO}: \"${BASH_COMMAND}\" returns ${?}." "ERROR"' ERR
trap json_output EXIT





################################################################################
# Constants
################################################################################

CPU_THRESHOLD_WARN=70
CPU_THRESHOLD_ERROR=85

DISK_THRESHOLD_WARN=45
DISK_THRESHOLD_ERROR=60





################################################################################
# Arguments
################################################################################

function usage {
    echo "Usage: check-temperatures.sh [-j] [-s] [-h]"
    echo "-j JSON output"
    echo "-s short (do not check disks)"
    echo "-h help"
    exit 0
}

json="{}"
short=1

while getopts "jsh" arg; do
  case $arg in
    j) JSON_OUTPUT=0 ;;
    s) short=0 ;;
    h) usage ;;
    *) usage ;;
  esac
done





################################################################################
# Main
################################################################################

# Get all temperatures except disks using sensors.
raw=$(sensors -j)

json=$(jq 'to_entries | map(. as $device | {
    key: $device.key,
    value: ($device.value | to_entries | map(. as $feature
        | select($feature.value | type == "object") | (
            $feature.value | to_entries
            | map(select(.key | test("^temp[0-9]+_input$")))
        ) as $temps
            | select($temps | length > 0) | {
                key: $feature.key,
                value: $temps[0].value
            }
        ) | from_entries
    )
} ) | from_entries' <<<"$raw")

# CPU temperature.
cpu_temp=$(echo $json | jq '.["coretemp-isa-0000"]["Package id 0"]' | grep -o '^[^\.]*')
if [ $cpu_temp -gt $CPU_THRESHOLD_ERROR ]; then
    logger "CPU temp ${cpu_temp} > ${CPU_THRESHOLD_ERROR}" "ERROR" "CPU"
elif [ $cpu_temp -gt $CPU_THRESHOLD_WARN ]; then
    logger "CPU temp ${cpu_temp} > ${CPU_THRESHOLD_WARN}" "WARN" "CPU"
else
    logger "CPU temp ${cpu_temp}" "INFO" "CPU"
fi

if ! [ $short -eq 0 ]; then
    # Checks that we are using the root account.
    if ! [ "$(whoami)" == "root" ]; then
        logger "Must be root for using smartctl." "ERROR"; exit 12
    fi
    # Disks temperatures.
    devices=$(/sbin/smartctl --scan | grep -o "^[^ ]*")
    for device in $devices; do
        if ! [[ $device =~ ^/dev/nvme[0-9]+$ ]] && (( $($CHECK_ACTIVITY $device) > $STANDBY_DELAY )); then
            # Do not read the temp from a standby disk as it would wake it up.
            json=$(echo $json | jq --arg target $device '.[$target] = {"disk":null}')
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
                json=$(echo $json | jq --arg target $device '.[$target] = {"disk":null}')
                logger "Disk ${device} SMART not enabled" "ERROR"
            }
            device_name=$(echo "${model_name} ${serial_number} ${disk_protocol}" | sed 's/[^a-zA-Z0-9]/_/g')
            json=$(echo $json | jq --arg target $device --argjson temp $disk_temp \
                '.[$target] = {"disk":$temp}')
            if [ $disk_temp -gt $DISK_THRESHOLD_ERROR ]; then
                logger "Disk ${device} temp ${disk_temp} > ${DISK_THRESHOLD_ERROR}" "ERROR" "$device_name"
            elif [ $disk_temp -gt $DISK_THRESHOLD_WARN ]; then
                logger "Disk ${device} temp ${disk_temp} > ${DISK_THRESHOLD_WARN}" "WARN" "$device_name"
            else
                logger "Disk ${device} temp ${disk_temp}" "INFO" "$device_name"
            fi
        fi
    done
fi
